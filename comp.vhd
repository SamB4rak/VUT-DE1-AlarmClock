-------------------------------------------------
--! @file comp.vhd
--! @brief Combinational equality comparator for current time and alarm time.
--! @description
--! Compares two packed BCD HH:MM values and asserts match when the current
--! time is identical to the stored alarm time. The output is intended for
--! the alarm-control FSM, where it is combined with the alarm_armed flag.
--!
--! Main behavior:
--! - time_in and alarm_in are 16-bit packed BCD values: h1 & h0 & m1 & m0.
--! - match='1' when every BCD digit is equal.
--! - match='0' for all non-equal values.
--!
--! Relevant notes:
--! - This module is purely combinational and has no clock or reset.
--!
--! @copyright Kapana, Glaser 2026
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity comp is
    port (
        time_in  : in  std_logic_vector(15 downto 0);
        alarm_in : in  std_logic_vector(15 downto 0);
        match    : out std_logic
    );
end entity comp;

architecture Behavioral of comp is
begin
    match <= '1' when (time_in = alarm_in) else '0';
end architecture Behavioral;
