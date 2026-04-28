-------------------------------------------------
--! @file clk_en.vhd
--! @brief Parameterized clock-enable pulse generator.
--! @description
--! Produces a one-clock-cycle enable pulse after G_MAX input clock cycles.
--! This allows slower timing events to be derived from the main system
--! clock without gating or creating a second clock domain.
--!
--! Main behavior:
--! - ce is asserted for exactly one rising-edge clock cycle.
--! - The counter restarts at zero after reaching G_MAX - 1.
--! - rst='1' synchronously clears the counter and deasserts ce.
--!
--! Typical 100 MHz settings:
--! - G_MAX = 50_000_000 gives a 1 Hz enable.
--! - G_MAX = 25_000_000 gives a 2 Hz enable.
--! - G_MAX = 100_000 gives an approximately 1 kHz enable.
--!
--! @copyright Kapana, Glaser 2026
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
