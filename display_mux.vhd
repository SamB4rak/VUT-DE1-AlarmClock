-------------------------------------------------
--! @brief 8-digit 7-segment display multiplexer
--! @version 3.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Nexys A7 anode numbering (active-low):
--!   an[7] = leftmost digit ... an[0] = rightmost digit
--!
--! Display layout:
--!   an[7] an[6] an[5] an[4]  an[3] an[2] an[1] an[0]
--!   h1    h0.   m1    m0     ah1   ah0.  am1   am0
--!   |--- TIME (left) ----|   |--- ALARM (right) ----|
--!
--!   DP on an[6] = time colon (blinks every sec)
--!   DP on an[2] = alarm colon (always on when armed)
--!
--! State encoding (from fsm_ctrl):
--!   "00" RUN        : normal display, time colon blinks
--!   "01" SET_TIME   : blink active digit on LEFT half
--!   "10" SET_ALARM  : blink active digit on RIGHT half
--!   "11" ALARM_RING : blink entire RIGHT half at 2 Hz
--!
--! digit_sel mapping:
--!   "00" = h1/ah1 (tens of hours)
--!   "01" = h0/ah0 (ones of hours)
--!   "10" = m1/am1 (tens of minutes)
--!   "11" = m0/am0 (ones of minutes)
--!
--! When alarm_armed='0', right half is blanked.
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_mux is
    generic (
        G_MUX_MAX : positive := 100_000
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- Data: {h1, h0, m1, m0}, 4 bits each
        time_in      : in  std_logic_vector(15 downto 0);
        alarm_in     : in  std_logic_vector(15 downto 0);

        -- Control
        state        : in  std_logic_vector(1 downto 0);
        digit_sel    : in  std_logic_vector(1 downto 0);
        sec_tick     : in  std_logic;      -- toggles every second
        ce_blink     : in  std_logic;      -- 2 Hz pulse
        alarm_armed  : in  std_logic;

        -- Display outputs (active-low)
        seg          : out std_logic_vector(6 downto 0);
        an           : out std_logic_vector(7 downto 0);
        dp           : out std_logic
    );
end entity display_mux;

architecture Behavioral of display_mux is

    constant ST_RUN  : std_logic_vector(1 downto 0) := "00";
    constant ST_SETT : std_logic_vector(1 downto 0) := "01";
    constant ST_SETA : std_logic_vector(1 downto 0) := "10";
    constant ST_RING : std_logic_vector(1 downto 0) := "11";

    signal mux_cnt   : unsigned(31 downto 0);
    signal scan_idx  : unsigned(2 downto 0);  -- 0..7
    signal blink_tog : std_logic;

    signal cur_bcd     : std_logic_vector(3 downto 0);
    signal cur_seg     : std_logic_vector(6 downto 0);
    signal blank_digit : std_logic;
    signal cur_dp      : std_logic;

begin

    ----------------------------------------------------------------
    -- Scan counter
    ----------------------------------------------------------------
    p_scan : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mux_cnt  <= (others => '0');
                scan_idx <= (others => '0');
            else
                if mux_cnt = G_MUX_MAX - 1 then
                    mux_cnt  <= (others => '0');
                    scan_idx <= scan_idx + 1;
                else
                    mux_cnt <= mux_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Blink toggle (2 Hz)
    ----------------------------------------------------------------
    p_blink : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                blink_tog <= '0';
            elsif ce_blink = '1' then
                blink_tog <= not blink_tog;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- BCD nibble selection + blanking + DP logic
    --
    -- Physical anode mapping on Nexys A7:
    --   scan_idx  anode   content     role
    --   7         an[7]   time h1     LEFT (time) - tens of hours
    --   6         an[6]   time h0     LEFT (time) - ones of hours + DP colon
    --   5         an[5]   time m1     LEFT (time) - tens of minutes
    --   4         an[4]   time m0     LEFT (time) - ones of minutes
    --   3         an[3]   alarm h1    RIGHT (alarm) - tens of hours
    --   2         an[2]   alarm h0    RIGHT (alarm) - ones of hours + DP colon
    --   1         an[1]   alarm m1    RIGHT (alarm) - tens of minutes
    --   0         an[0]   alarm m0    RIGHT (alarm) - ones of minutes
    --
    -- digit_sel for SET modes:
    --   "00" = h1 -> scan 7 (time) or 3 (alarm)
    --   "01" = h0 -> scan 6 (time) or 2 (alarm)
    --   "10" = m1 -> scan 5 (time) or 1 (alarm)
    --   "11" = m0 -> scan 4 (time) or 0 (alarm)
    ----------------------------------------------------------------
    p_select : process(scan_idx, time_in, alarm_in,
                       state, digit_sel, blink_tog, sec_tick,
                       alarm_armed)
        variable v_idx       : integer range 0 to 7;
        variable v_blank     : std_logic;
        variable v_dp        : std_logic;
        variable v_left_half : boolean;
        variable v_digit_pos : std_logic_vector(1 downto 0);  -- which digit within its half
    begin
        v_idx       := 0;
        v_blank     := '0';
        v_dp        := '0';
        v_left_half := true;
        cur_bcd     <= (others => '0');

        -- Select BCD nibble based on scan_idx
        -- time_in  = {h1[15:12], h0[11:8], m1[7:4], m0[3:0]}
        -- alarm_in = {ah1[15:12], ah0[11:8], am1[7:4], am0[3:0]}
        case scan_idx is
            when "111" => v_idx := 7; cur_bcd <= time_in(15 downto 12);   -- an[7] = time h1
            when "110" => v_idx := 6; cur_bcd <= time_in(11 downto 8);    -- an[6] = time h0
            when "101" => v_idx := 5; cur_bcd <= time_in(7 downto 4);     -- an[5] = time m1
            when "100" => v_idx := 4; cur_bcd <= time_in(3 downto 0);     -- an[4] = time m0
            when "011" => v_idx := 3; cur_bcd <= alarm_in(15 downto 12);  -- an[3] = alarm h1
            when "010" => v_idx := 2; cur_bcd <= alarm_in(11 downto 8);   -- an[2] = alarm h0
            when "001" => v_idx := 1; cur_bcd <= alarm_in(7 downto 4);    -- an[1] = alarm m1
            when "000" => v_idx := 0; cur_bcd <= alarm_in(3 downto 0);    -- an[0] = alarm m0
            when others => v_idx := 0; cur_bcd <= (others => '0');
        end case;

        v_left_half := (v_idx >= 4);  -- an[4..7] = LEFT = time

        ----------------------------------------------------------
        -- DP logic (DP is active on the h0 position = between H and M)
        ----------------------------------------------------------
        -- Time colon: DP on an[6] (time h0), blinks with sec_tick
        if v_idx = 6 then
            v_dp := sec_tick;
        end if;

        -- Alarm colon: DP on an[2] (alarm h0), always on when armed or setting
        if v_idx = 2 then
            if alarm_armed = '1' or state = ST_SETA then
                v_dp := '1';
            end if;
        end if;

        ----------------------------------------------------------
        -- Blanking logic
        ----------------------------------------------------------
        -- RIGHT half (alarm): blank when not armed and not setting alarm
        if not v_left_half then
            if alarm_armed = '0' and state /= ST_SETA then
                v_blank := '1';
                v_dp    := '0';
            end if;
        end if;

        -- ALARM_RING: blink entire RIGHT half + DP at 2 Hz
        if state = ST_RING and not v_left_half then
            if blink_tog = '0' then
                v_blank := '1';
                v_dp    := '0';
            end if;
        end if;

        -- SET_TIME: blink the active digit on LEFT half
        -- digit_sel "00"=h1 maps to scan 7, "01"=h0 to 6, "10"=m1 to 5, "11"=m0 to 4
        if state = ST_SETT and v_left_half then
            v_digit_pos := std_logic_vector(to_unsigned(7 - v_idx, 2));
            if digit_sel = v_digit_pos and blink_tog = '0' then
                v_blank := '1';
            end if;
        end if;

        -- SET_ALARM: blink the active digit on RIGHT half
        -- digit_sel "00"=ah1 maps to scan 3, "01"=ah0 to 2, "10"=am1 to 1, "11"=am0 to 0
        if state = ST_SETA and not v_left_half then
            v_digit_pos := std_logic_vector(to_unsigned(3 - v_idx, 2));
            if digit_sel = v_digit_pos and blink_tog = '0' then
                v_blank := '1';
            end if;
        end if;

        blank_digit <= v_blank;
        cur_dp      <= v_dp;
    end process;

    ----------------------------------------------------------------
    -- BCD -> 7-seg decoder (active-low cathodes)
    -- seg(6)=CA ... seg(0)=CG
    ----------------------------------------------------------------
    p_decode : process(cur_bcd)
    begin
        case cur_bcd is
            when "0000" => cur_seg <= "0000001";  -- 0
            when "0001" => cur_seg <= "1001111";  -- 1
            when "0010" => cur_seg <= "0010010";  -- 2
            when "0011" => cur_seg <= "0000110";  -- 3
            when "0100" => cur_seg <= "1001100";  -- 4
            when "0101" => cur_seg <= "0100100";  -- 5
            when "0110" => cur_seg <= "0100000";  -- 6
            when "0111" => cur_seg <= "0001111";  -- 7
            when "1000" => cur_seg <= "0000000";  -- 8
            when "1001" => cur_seg <= "0000100";  -- 9
            when others => cur_seg <= "1111111";  -- blank
        end case;
    end process;

    ----------------------------------------------------------------
    -- Anode + segment drive (active-low)
    ----------------------------------------------------------------
    p_drive : process(scan_idx, cur_seg, blank_digit, cur_dp)
        variable v_an : std_logic_vector(7 downto 0);
    begin
        v_an := (others => '1');           -- all off
        case scan_idx is
            when "000"  => v_an(0) := '0';
            when "001"  => v_an(1) := '0';
            when "010"  => v_an(2) := '0';
            when "011"  => v_an(3) := '0';
            when "100"  => v_an(4) := '0';
            when "101"  => v_an(5) := '0';
            when "110"  => v_an(6) := '0';
            when "111"  => v_an(7) := '0';
            when others => null;
        end case;
        an <= v_an;

        if blank_digit = '1' then
            seg <= (others => '1');
            dp  <= '1';
        else
            seg <= cur_seg;
            dp  <= not cur_dp;    -- invert: internal '1' -> output '0' (DP on)
        end if;
    end process;

end architecture Behavioral;
