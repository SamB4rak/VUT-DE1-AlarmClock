-------------------------------------------------
--! @brief 24-hour BCD alarm register (HH:MM)
--! @version 1.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Stores the alarm time as four BCD digits:
--!   h1 (0-2), h0 (0-9 / 0-3), m1 (0-5), m0 (0-9)
--! No automatic counting - values only change via
--! manual inc/dec pulses from the FSM when in SET_ALARM
--! state, with the same BCD range rules as time_counter.
--
-- Notes:
-- - Synchronous design (rising edge of clk)
-- - High-active synchronous reset -> 00:00
-- - inc_en/dec_en pulses trigger a one-step change
--   to the digit selected by digit_sel(1:0):
--     "00" = h1, "01" = h0, "10" = m1, "11" = m0
-- - alarm_out = h1 & h0 & m1 & m0 (4 bits each, MSB first)
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alarm_reg is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        inc_en    : in  std_logic;                     -- manual increment pulse
        dec_en    : in  std_logic;                     -- manual decrement pulse
        digit_sel : in  std_logic_vector(1 downto 0);  -- which digit to modify
        alarm_out : out std_logic_vector(15 downto 0)  -- {h1, h0, m1, m0}
    );
end entity alarm_reg;

architecture Behavioral of alarm_reg is
    signal h1 : unsigned(3 downto 0);
    signal h0 : unsigned(3 downto 0);
    signal m1 : unsigned(3 downto 0);
    signal m0 : unsigned(3 downto 0);

    function h0_max(hh1 : unsigned(3 downto 0)) return unsigned is
    begin
        if hh1 = 2 then
            return to_unsigned(3, 4);
        else
            return to_unsigned(9, 4);
        end if;
    end function;

begin

    p_alarm : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                h1 <= (others => '0');
                h0 <= (others => '0');
                m1 <= (others => '0');
                m0 <= (others => '0');

            elsif inc_en = '1' then
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
    end process;

    alarm_out <= std_logic_vector(h1) &
                 std_logic_vector(h0) &
                 std_logic_vector(m1) &
                 std_logic_vector(m0);

end architecture Behavioral;
