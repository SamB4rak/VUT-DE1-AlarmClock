-------------------------------------------------
--! @brief 24-hour BCD time counter (HH:MM)
--! @version 1.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Stores hours and minutes as four BCD digits:
--!   h1 (0-2), h0 (0-9), m1 (0-5), m0 (0-9)
--! Automatically counts 1 Hz (via ce_run) in RUN mode,
--! with proper 23:59 -> 00:00 rollover.
--! Supports manual inc/dec of a selected digit for SET
--! mode with BCD constraints (each digit has own range).
--
-- Notes:
-- - Synchronous design (rising edge of clk)
-- - High-active synchronous reset -> 00:00
-- - inc_en/dec_en pulses trigger a one-step change
--   to the digit selected by digit_sel(1:0):
--     "00" = h1, "01" = h0, "10" = m1, "11" = m0
-- - Wrap rules within each digit (no propagation):
--     h1: 0..2
--     h0: 0..9 if h1<2, else 0..3
--     m1: 0..5
--     m0: 0..9
-- - time_out = h1 & h0 & m1 & m0 (4 bits each, MSB first)
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity time_counter is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        ce_run    : in  std_logic;                     -- 1 Hz enable for auto counting
        run_en    : in  std_logic;                     -- '1' = RUN (auto count), '0' = HOLD/SET
        inc_en    : in  std_logic;                     -- manual increment pulse
        dec_en    : in  std_logic;                     -- manual decrement pulse
        digit_sel : in  std_logic_vector(1 downto 0);  -- which digit to modify
        time_out  : out std_logic_vector(15 downto 0)  -- {h1, h0, m1, m0}
    );
end entity time_counter;

architecture Behavioral of time_counter is
    signal h1 : unsigned(3 downto 0);
    signal h0 : unsigned(3 downto 0);
    signal m1 : unsigned(3 downto 0);
    signal m0 : unsigned(3 downto 0);

    -- Maximum value for h0 depends on h1:
    -- h1 = 2 -> h0 max = 3 (for 23:59)
    -- h1 < 2 -> h0 max = 9
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
                h1 <= (others => '0');
                h0 <= (others => '0');
                m1 <= (others => '0');
                m0 <= (others => '0');

            elsif run_en = '1' then
                ------------------------------------------------
                -- RUN mode: auto count every 1 Hz pulse
                ------------------------------------------------
                if ce_run = '1' then
                    -- increment minutes ones
                    if m0 = 9 then
                        m0 <= (others => '0');
                        -- increment minutes tens
                        if m1 = 5 then
                            m1 <= (others => '0');
                            -- increment hours ones
                            if h0 = h0_max(h1) then
                                h0 <= (others => '0');
                                -- increment hours tens
                                if h1 = 2 then
                                    h1 <= (others => '0');   -- 23:59 -> 00:00
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
                end if;

            else
                ------------------------------------------------
                -- SET mode: manual inc/dec of selected digit
                ------------------------------------------------
                if inc_en = '1' then
                    case digit_sel is
                        when "00" =>  -- h1: 0..2
                            if h1 = 2 then
                                h1 <= (others => '0');
                                -- if h0 was > 3, clip it to keep valid time
                                if h0 > 3 then
                                    h0 <= to_unsigned(3, 4);
                                end if;
                            else
                                h1 <= h1 + 1;
                                -- entering h1=2 range: clip h0 if needed
                                if h1 = 1 and h0 > 3 then
                                    h0 <= to_unsigned(3, 4);
                                end if;
                            end if;

                        when "01" =>  -- h0: 0..9 or 0..3
                            if h0 = h0_max(h1) then
                                h0 <= (others => '0');
                            else
                                h0 <= h0 + 1;
                            end if;

                        when "10" =>  -- m1: 0..5
                            if m1 = 5 then
                                m1 <= (others => '0');
                            else
                                m1 <= m1 + 1;
                            end if;

                        when others => -- "11" m0: 0..9
                            if m0 = 9 then
                                m0 <= (others => '0');
                            else
                                m0 <= m0 + 1;
                            end if;
                    end case;

                elsif dec_en = '1' then
                    case digit_sel is
                        when "00" =>  -- h1: 0..2
                            if h1 = 0 then
                                h1 <= to_unsigned(2, 4);
                                if h0 > 3 then
                                    h0 <= to_unsigned(3, 4);
                                end if;
                            else
                                h1 <= h1 - 1;
                            end if;

                        when "01" =>  -- h0
                            if h0 = 0 then
                                h0 <= h0_max(h1);
                            else
                                h0 <= h0 - 1;
                            end if;

                        when "10" =>  -- m1
                            if m1 = 0 then
                                m1 <= to_unsigned(5, 4);
                            else
                                m1 <= m1 - 1;
                            end if;

                        when others => -- m0
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
    -- Output assembly
    ----------------------------------------------------------------
    time_out <= std_logic_vector(h1) &
                std_logic_vector(h0) &
                std_logic_vector(m1) &
                std_logic_vector(m0);

end architecture Behavioral;
