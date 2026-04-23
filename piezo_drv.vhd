-------------------------------------------------
--! @brief Piezo buzzer square-wave driver
--! @version 1.0
--! @copyright (c) 2026 Jarda, MIT license
--!
--! Generates a ~1 kHz square wave on the piezo
--! output while ringing='1'. When ringing='0',
--! the output is held at '0' (silent).
--
-- Notes:
-- - 100 MHz clk / (2 * G_HALF_PERIOD) = tone frequency
-- - G_HALF_PERIOD = 50_000 -> ~1 kHz
-- - For simulation set G_HALF_PERIOD small (e.g. 10)
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity piezo_drv is
    generic (
        G_HALF_PERIOD : positive := 50_000
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        ringing : in  std_logic;
        piezo   : out std_logic
    );
end entity piezo_drv;

architecture Behavioral of piezo_drv is
    signal cnt    : unsigned(31 downto 0);
    signal toggle : std_logic;
begin

    p_tone : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt    <= (others => '0');
                toggle <= '0';
            elsif ringing = '1' then
                if cnt = G_HALF_PERIOD - 1 then
                    cnt    <= (others => '0');
                    toggle <= not toggle;
                else
                    cnt <= cnt + 1;
                end if;
            else
                cnt    <= (others => '0');
                toggle <= '0';
            end if;
        end if;
    end process;

    piezo <= toggle;

end architecture Behavioral;
