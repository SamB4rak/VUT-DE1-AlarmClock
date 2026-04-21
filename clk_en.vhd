-------------------------------------------------
--! @brief Clock enable generator
--! @version 1.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Generates a single-clock-cycle pulse every G_MAX
--! cycles of the input clock. Used to derive slow
--! enables (1 Hz, 2 Hz, ~1 kHz) from the 100 MHz
--! system clock without gating the actual clock.
--
-- Notes:
-- - Synchronous design (rising edge of clk)
-- - High-active synchronous reset
-- - G_MAX = 50_000_000 -> 1 Hz from 100 MHz clock
-- - G_MAX = 25_000_000 -> 2 Hz from 100 MHz clock
-- - G_MAX = 100_000    -> 1 kHz from 100 MHz clock
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_en is
    generic (
        G_MAX : positive := 100_000_000
    );
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        ce  : out std_logic
    );
end entity clk_en;

architecture Behavioral of clk_en is
    signal cnt : unsigned(31 downto 0);
begin

    p_counter : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt <= (others => '0');
                ce  <= '0';
            else
                if cnt = G_MAX - 1 then
                    cnt <= (others => '0');
                    ce  <= '1';
                else
                    cnt <= cnt + 1;
                    ce  <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture Behavioral;
