-------------------------------------------------
--! @brief 8-digit 7-segment display multiplexer
--! @version 1.0
--! @copyright (c)
--!
--! Drives the Nexys A7 8-digit 7-seg display.
--! Layout:
--!   an(0..3) = LEFT  4 digits  -> time HH:MM
--!   an(4..7) = RIGHT 4 digits  -> alarm HH:MM
--!
--! Decimal point (colon emulation):
--!   an(1) DP = blinks at 1 Hz (toggle by ce_1hz) when in RUN mode
--!   an(5) DP = always on (alarm colon)
--!
--! State-driven behavior (state encoding from fsm_ctrl):
--!   "00" RUN        : show time + alarm normally
--!   "01" SET_TIME   : blink the active digit on LEFT half
--!   "10" SET_ALARM  : blink the active digit on RIGHT half
--!   "11" ALARM_RING : blink entire RIGHT half + DP at 2 Hz
--!
--! When alarm_armed='0' (after user dismisses alarm),
--! the right half is fully blanked until re-armed.
--!
--! Multiplex frequency: ~1 kHz (set via clk_en or local divider)
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_mux is
    generic (
        G_MUX_MAX : positive := 100_000   -- ~1 kHz from 100 MHz
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- Data
        time_in      : in  std_logic_vector(15 downto 0);
        alarm_in     : in  std_logic_vector(15 downto 0);

        -- Control from FSM
        state        : in  std_logic_vector(1 downto 0);  -- RUN/SETT/SETA/RING
        digit_sel    : in  std_logic_vector(1 downto 0);  -- which digit is active in SET
        ce_1hz       : in  std_logic;                     -- 1 Hz pulse for time colon
        ce_blink     : in  std_logic;                     -- 2 Hz pulse for digit/alarm blink
        alarm_armed  : in  std_logic;                     -- '1' = alarm is set

        -- Display outputs (active-low for Nexys A7)
        seg          : out std_logic_vector(6 downto 0);
        an           : out std_logic_vector(7 downto 0);
        dp           : out std_logic
    );
end entity display_mux;

architecture Behavioral of display_mux is

    -- State encoding (must match fsm_ctrl)
    constant ST_RUN  : std_logic_vector(1 downto 0) := "00";
    constant ST_SETT : std_logic_vector(1 downto 0) := "01";
    constant ST_SETA : std_logic_vector(1 downto 0) := "10";
    constant ST_RING : std_logic_vector(1 downto 0) := "11";

    -- Mux scan counter
    signal mux_cnt   : unsigned(31 downto 0);
    signal scan_idx  : unsigned(2 downto 0);  -- 0..7 active digit

    -- Blink toggles (visible state)
    signal colon_tog : std_logic;             -- toggles at 1 Hz, controls time DP
    signal blink_tog : std_logic;             -- toggles at 2 Hz, controls active digit & ring

    -- Currently selected BCD nibble
    signal cur_bcd   : std_logic_vector(3 downto 0);
    signal cur_seg   : std_logic_vector(6 downto 0);

    -- Per-digit blank decisions
    signal blank_digit : std_logic;
    signal cur_dp      : std_logic;  -- active-high internal, inverted at output

begin

    ----------------------------------------------------------------
    -- Mux scan counter (~1 kHz)
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
    -- Blink toggles: derived from ce_1hz and ce_blink pulses
    ----------------------------------------------------------------
   p_blink : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                colon_tog <= '0';
                blink_tog <= '0';
            else
                if ce_1hz = '1' then
                    colon_tog <= not colon_tog;
                end if;
                if ce_blink = '1' then
                    blink_tog <= not blink_tog;
                end if;
            end if;
        end if;
    end process;

    -- sec_pulse: pro debug - colon_tog by se měl překlápět každou sekundu
    -- Pokud nebliká, zkontroluj XDC: create_clock -period 10.000 [get_ports clk]

    ----------------------------------------------------------------
    -- Select BCD nibble for current scan position
    -- Mapping of scan_idx -> source nibble:
    --   0 -> time h1   (an[0])
    --   1 -> time h0   (an[1])  + DP for time colon
    --   2 -> time m1   (an[2])
    --   3 -> time m0   (an[3])
    --   4 -> alarm h1  (an[4])
    --   5 -> alarm h0  (an[5])  + DP for alarm colon
    --   6 -> alarm m1  (an[6])
    --   7 -> alarm m0  (an[7])
    ----------------------------------------------------------------
    p_select : process(scan_idx, time_in, alarm_in,
                       state, digit_sel, blink_tog, colon_tog,
                       alarm_armed)
        variable v_idx       : integer range 0 to 7;
        variable v_blank     : std_logic;
        variable v_dp        : std_logic;
        variable v_active_dg : std_logic_vector(1 downto 0);
        variable v_left_half : boolean;
    begin
        -- Defaults (used also when scan_idx is metavalue at sim start)
        v_idx       := 0;
        v_blank     := '0';
        v_dp        := '0';
        v_left_half := true;
        cur_bcd     <= (others => '0');

        -- Decode scan_idx safely
        case scan_idx is
            when "000" => v_idx := 0; cur_bcd <= time_in(15 downto 12);
            when "001" => v_idx := 1; cur_bcd <= time_in(11 downto 8);
            when "010" => v_idx := 2; cur_bcd <= time_in(7 downto 4);
            when "011" => v_idx := 3; cur_bcd <= time_in(3 downto 0);
            when "100" => v_idx := 4; cur_bcd <= alarm_in(15 downto 12);
            when "101" => v_idx := 5; cur_bcd <= alarm_in(11 downto 8);
            when "110" => v_idx := 6; cur_bcd <= alarm_in(7 downto 4);
            when "111" => v_idx := 7; cur_bcd <= alarm_in(3 downto 0);
            when others => v_idx := 0; cur_bcd <= (others => '0');
        end case;

        v_left_half := (v_idx <= 3);

        ----------------------------------------------------------
        -- Decimal point logic
        ----------------------------------------------------------
        -- Time colon at an[1] (h0 of time): blinks at 1 Hz in RUN/SET states
        if v_idx = 1 then
            if state = ST_RUN or state = ST_SETT then
                v_dp := colon_tog;          -- blink with 1 Hz toggle
            else
                v_dp := '1';                -- always on otherwise
            end if;
        end if;

        -- Alarm colon at an[5] (h0 of alarm): always on when alarm_armed
        if v_idx = 5 then
            if alarm_armed = '1' or state = ST_SETA then
                v_dp := '1';
            else
                v_dp := '0';
            end if;
        end if;

        ----------------------------------------------------------
        -- Blanking logic
        ----------------------------------------------------------
        -- Right half: if alarm not armed AND not currently being set,
        -- blank entire right half
        if not v_left_half then
            if alarm_armed = '0' and state /= ST_SETA then
                v_blank := '1';
                v_dp    := '0';
            end if;
        end if;

        -- ALARM_RING: blink right half + DP at 2 Hz
        if state = ST_RING and not v_left_half then
            if blink_tog = '0' then
                v_blank := '1';
                v_dp    := '0';
            end if;
        end if;

        -- SET_TIME: blink the currently selected digit on LEFT half
        if state = ST_SETT and v_left_half then
            v_active_dg := std_logic_vector(to_unsigned(v_idx, 2));
            if digit_sel = v_active_dg and blink_tog = '0' then
                v_blank := '1';
            end if;
        end if;

        -- SET_ALARM: blink the currently selected digit on RIGHT half
        if state = ST_SETA and not v_left_half then
            v_active_dg := std_logic_vector(to_unsigned(v_idx - 4, 2));
            if digit_sel = v_active_dg and blink_tog = '0' then
                v_blank := '1';
            end if;
        end if;

        blank_digit <= v_blank;
        cur_dp      <= v_dp;
    end process;

    ----------------------------------------------------------------
    -- BCD -> 7-seg decoder (active-low cathodes)
    -- seg(6)=A, seg(5)=B, seg(4)=C, seg(3)=D, seg(2)=E, seg(1)=F, seg(0)=G
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
    -- Anode + segment outputs (active-low for Nexys A7)
    ----------------------------------------------------------------
    p_drive : process(scan_idx, cur_seg, blank_digit, cur_dp)
        variable v_an : std_logic_vector(7 downto 0);
    begin
        v_an := (others => '1');           -- all digits off (active-low)
        -- Only drive active anode if scan_idx is a valid value
        case scan_idx is
            when "000"  => v_an(7) := '0';
            when "001"  => v_an(6) := '0';
            when "010"  => v_an(5) := '0';
            when "011"  => v_an(4) := '0';
            when "100"  => v_an(3) := '0';
            when "101"  => v_an(2) := '0';
            when "110"  => v_an(1) := '0';
            when "111"  => v_an(0) := '0';
            when others => null;            -- 'U'/'X' -> all anodes stay '1'
        end case;
        an <= v_an;

        if blank_digit = '1' then
            seg <= (others => '1');        -- all segments off
            dp  <= '1';                    -- DP off
        else
            seg <= cur_seg;
            dp  <= not cur_dp;             -- invert to active-low
        end if;
    end process;

end architecture Behavioral;
