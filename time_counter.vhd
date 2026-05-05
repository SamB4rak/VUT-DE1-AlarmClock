-------------------------------------------------
--! @brief 24-hour BCD time counter (HH:MM:SS)
--! @version 2.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Internal seconds counter 0..59, plus four BCD digits
--! for hours and minutes: h1 (0-2), h0 (0-9), m1 (0-5), m0 (0-9).
--!
--! In RUN mode, ce_run (1 Hz) increments seconds.
--! After 60 seconds, m0 increments (= one real minute).
--! After 59 minutes, hours increment.
--! Rollover at 23:59:59 -> 00:00:00.
--!
--! sec_tick output toggles every second (for colon blink).
--!
--! In SET mode, inc_en/dec_en modify the selected digit
--! with BCD range constraints.
--
-- Notes:
-- - time_out = h1 & h0 & m1 & m0 (4 bits each = 16 bits)
-- - Seconds are internal only (not on display)
-- - digit_sel: "00"=h1, "01"=h0, "10"=m1, "11"=m0
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity time_counter is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        ce_run    : in  std_logic;                     -- 1 Hz enable
        run_en    : in  std_logic;                     -- '1' = RUN, '0' = SET
        inc_en    : in  std_logic;                     -- manual increment pulse
        dec_en    : in  std_logic;                     -- manual decrement pulse
        digit_sel : in  std_logic_vector(1 downto 0);  -- which digit to modify
        time_out  : out std_logic_vector(15 downto 0); -- {h1, h0, m1, m0}
        sec_tick  : out std_logic                      -- toggles every second (for DP blink)
    );
end entity time_counter;

architecture Behavioral of time_counter is
    signal sec : unsigned(5 downto 0);   -- 0..59
    signal h1  : unsigned(3 downto 0);
    signal h0  : unsigned(3 downto 0);
    signal m1  : unsigned(3 downto 0);
    signal m0  : unsigned(3 downto 0);

    signal sec_tog : std_logic;          -- toggles on every ce_run

    function h0_max(hh1 : unsigned(3 downto 0)) return unsigned is
    begin
        if hh1 = 2 then
            return to_unsigned(3, 4);
        else
            return to_unsigned(9, 4);
        end if;
    end function;

begin

    p_time : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sec     <= (others => '0');
                h1      <= (others => '0');
                h0      <= (others => '0');
                m1      <= (others => '0');
                m0      <= (others => '0');
                sec_tog <= '0';

            elsif run_en = '1' then
                ------------------------------------------------
                -- RUN mode: count seconds, carry into minutes
                ------------------------------------------------
                if ce_run = '1' then
                    -- toggle for DP blink (every second)
                    sec_tog <= not sec_tog;

                    if sec = 59 then
                        sec <= (others => '0');

                        -- === carry into minutes ===
                        if m0 = 9 then
                            m0 <= (others => '0');
                            if m1 = 5 then
                                m1 <= (others => '0');
                                -- === carry into hours ===
                                if h0 = h0_max(h1) then
                                    h0 <= (others => '0');
                                    if h1 = 2 then
                                        h1 <= (others => '0');
                                    else
                                        h1 <= h1 + 1;
                                    end if;
                                else
                                    h0 <= h0 + 1;
                                end if;
                            else
                                m1 <= m1 + 1;
                            end if;
                        else
                            m0 <= m0 + 1;
                        end if;
                    else
                        sec <= sec + 1;
                    end if;
                end if;

            else
                ------------------------------------------------
                -- SET mode: manual inc/dec of selected digit
                -- Seconds reset to 0 when entering SET mode
                ------------------------------------------------
                sec <= (others => '0');

                if inc_en = '1' then
                    case digit_sel is
                        when "00" =>
                            if h1 = 2 then
                                h1 <= (others => '0');
                                if h0 > 3 then
                                    h0 <= to_unsigned(3, 4);
                                end if;
                            else
                                h1 <= h1 + 1;
                                if h1 = 1 and h0 > 3 then
                                    h0 <= to_unsigned(3, 4);
                                end if;
                            end if;

                        when "01" =>
                            if h0 = h0_max(h1) then
                                h0 <= (others => '0');
                            else
                                h0 <= h0 + 1;
                            end if;

                        when "10" =>
                            if m1 = 5 then
                                m1 <= (others => '0');
                            else
                                m1 <= m1 + 1;
                            end if;

                        when others =>
                            if m0 = 9 then
                                m0 <= (others => '0');
                            else
                                m0 <= m0 + 1;
                            end if;
                    end case;

                elsif dec_en = '1' then
                    case digit_sel is
                        when "00" =>
                            if h1 = 0 then
                                h1 <= to_unsigned(2, 4);
                                if h0 > 3 then
                                    h0 <= to_unsigned(3, 4);
                                end if;
                            else
                                h1 <= h1 - 1;
                            end if;

                        when "01" =>
                            if h0 = 0 then
                                h0 <= h0_max(h1);
                            else
                                h0 <= h0 - 1;
                            end if;

                        when "10" =>
                            if m1 = 0 then
                                m1 <= to_unsigned(5, 4);
                            else
                                m1 <= m1 - 1;
                            end if;

                        when others =>
                            if m0 = 0 then
                                m0 <= to_unsigned(9, 4);
                            else
                                m0 <= m0 - 1;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------
    time_out <= std_logic_vector(h1) &
                std_logic_vector(h0) &
                std_logic_vector(m1) &
                std_logic_vector(m0);

    sec_tick <= sec_tog;

end architecture Behavioral;
