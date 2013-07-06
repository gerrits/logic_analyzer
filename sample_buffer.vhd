----------------------------------------------------------------------------------
-- Company: BRD GmbH fuer effiziente Speicherverwaltung
-- Engineer: 
-- 
-- Create Date:    17:45:23 06/21/2013 
-- Design Name: 
-- Module Name:    sample_buffer - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sample_buffer is

port(CLK : in std_logic;
	  RST : in std_logic;
	  INPUT : in std_logic_vector(7 downto 0);
	  INPUT_ADDR : in std_logic_vector(14 downto 0);
	  OUTPUT_ADDR : in std_logic_vector(14 downto 0);
	  OUTPUT : out std_logic_vector(7 downto 0);
	  RW     : in std_logic
	  );
	  
end entity sample_buffer;

architecture Behavioral of sample_buffer is

type RAM_T is array(32768 downto 0) of std_logic_vector(7 downto 0) ;-- := ((others => (others => '0')));
signal RAM : RAM_T;

begin
	process(CLK)
	begin
		if(rising_edge(CLK)) then
			
			if (RW = '1') then
				RAM(conv_integer(INPUT_ADDR)) <= INPUT;
			end if;
		
			OUTPUT <= RAM(conv_integer(OUTPUT_ADDR));
			
		end if;
	end process;
end Behavioral;

