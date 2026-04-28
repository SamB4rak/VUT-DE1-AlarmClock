-------------------------------------------------
--! @file piezo_drv.vhd
--! @brief Square-wave driver for a piezo buzzer.
--! @description
--! Generates an audible square wave while the alarm is ringing. When the
--! ringing input is low, the internal counter is cleared and the piezo
--! output is forced low so the buzzer remains silent.
--!
--! Main behavior:
--! - ringing='1' enables tone generation.
--! - ringing='0' disables the tone and clears the phase/counter.
--! - The output toggles every G_HALF_PERIOD clock cycles.
--!
--! Relevant notes:
--! - Tone frequency is clk_frequency / (2 * G_HALF_PERIOD).
--! - G_HALF_PERIOD = 50_000 gives about 1 kHz from a 100 MHz clock.
--! - Use a smaller G_HALF_PERIOD for faster simulation.
--!
--! @copyright Kapana, Glaser 2026
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
