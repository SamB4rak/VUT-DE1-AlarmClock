-------------------------------------------------
--! @file alarm_reg.vhd
--! @brief Editable 24-hour alarm-time register in packed BCD format.
--! @description
--! Stores the alarm setting as four BCD digits in HH:MM format and updates
--! only when the control FSM issues manual increment or decrement pulses.
--! The register does not count automatically; it only holds the selected
--! alarm time until edited again or reset.
--!
--! Main behavior:
--! - rst='1' resets the alarm to 00:00.
--! - inc_en and dec_en change one selected digit per clock pulse.
--! - digit_sel selects h1, h0, m1, or m0 using "00", "01", "10", "11".
--! - Hour digits are constrained to the valid 00..23 range.
--! - Minute digits are constrained to the valid 00..59 range.
--! - alarm_out packs the digits as h1 & h0 & m1 & m0.
--!
--! Relevant notes:
--! - The design is fully synchronous to clk.
--! - h0_max() limits the hour-ones digit to 3 when h1 is 2.
--!
--! @copyright Kapana, Glaser 2026
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
