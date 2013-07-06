----------------------------------------------------------------------------------
-- Company: BRD GmbH
-- Engineer: Dr. Axel Stoll
-- Create Date:    12:41:54 06/19/2013 
-- Module Name:    logic_analyzer - Behavioral
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.

library UNISIM;
use UNISIM.VComponents.all;

entity logic_analyzer is
port(
	  CLK 			: in std_logic;
     RST 			: in std_logic;
	  SW 				: in std_logic_vector(7 downto 0);
	  HSYNC, VSYNC : out std_logic; -- HSYNC / VSYNC Signal -> to monitor (ucf)
	  VGA_RED 		: out std_logic_vector (3 downto 1); -- Colors -> to monitor (ucf)
	  VGA_GREEN 	: out std_logic_vector (3 downto 1);
	  VGA_BLUE 		: out std_logic_vector (3 downto 1)
);
end logic_analyzer;

 architecture Behavioral of logic_analyzer is
-- Clock Signals
	signal CLKFX_40Mhz : std_logic; -- DCM Clk Output
	
-- VGA Controller Signals
	signal HCOUNT : std_logic_vector(10 downto 0); -- Horiz. Pixel Counter (user output)
	signal VCOUNT : std_logic_vector(10 downto 0); -- Vert. Pixel Counter
	signal BLANK : std_logic;
	
	--other
	signal RED_IN : std_logic_vector(3 downto 1);
	signal FRAME_COUNTER : std_logic_vector(20 downto 0) := (others => '0');
	signal RAM_CLK : std_logic := '1';
	
	signal ADDR_COUNTER : std_logic_vector ( 14 downto 0) := "000000000001000";
	signal SAMPLE_BUFFER_OUT : std_logic_vector(7 downto 0);
	signal timeSlot : std_logic_vector(14 downto 0);
	signal OFFSET : std_logic_vector(14 downto 0) := (others => '0');
	
	signal WRITE_EN : std_logic;
begin
	--calculate the read address for the timeslot we will be showing
	timeSlot <= ("0000000000000" & HCOUNT(8 downto 6)) + OFFSET;
	
	-- Switch0 also sets WE
	WRITE_EN <= RAM_CLK and SW(0);
	
	---renderer 
	process(VCOUNT, BLANK, SAMPLE_BUFFER_OUT, HCOUNT)
		variable index : std_logic_vector(2 downto 0);
		variable line 	: std_logic_vector(5 downto 1);
		variable row   : std_logic_vector(2 downto 0);
	begin
		VGA_RED   <= "000";
		VGA_GREEN <= "000";
		VGA_BLUE  <= "000";
		
		index := VCOUNT(8 downto 6); -- the 
		line 	:= VCOUNT(5 downto 1);
		row 	:= HCOUNT(8 downto 6);
		
		--SAMPLE BUFFER OUT: The current timeslot value based on HCOUNT
		if(VCOUNT(10 downto 9) = "00" and BLANK = '0') then
				if(conv_integer(HCOUNT) < 512) then
					if(line(5 downto 4)="11") then --white line
						VGA_RED 		<= "100";
						VGA_GREEN 	<= "100";
						VGA_BLUE 	<= "100";
					elsif(conv_integer(line)=8 --upper line
							and SAMPLE_BUFFER_OUT(conv_integer(index)) = '1') then
						VGA_GREEN 	<= "111";
					elsif(conv_integer(line)=16 --lower line
							and SAMPLE_BUFFER_OUT(conv_integer(index)) = '0') then
						VGA_RED 		<= "111";
					end if;
				end if;
		end if;
	end process;

	process(CLK, RST)
	begin
		if(rising_edge(CLK)) then
			if(conv_integer(FRAME_COUNTER) = 0) then -- frame counter overflowed, one half frame is over
			
				if(RST = '1') then
					ADDR_COUNTER  <= "000000000001000"; -- 8 we want to start writing at sample 8
					OFFSET 		  <= (others => '0');
					FRAME_COUNTER <= (others => '0');
				end if;
				
				--RAM_CLK ( the WE of the RAM) is 0 so it will be flipped, increment Write-Address
				if(RAM_CLK = '0') then
					ADDR_COUNTER  <= ADDR_COUNTER +1; -- increment ADDR_COUNTER ( Write Address )
				end if;
				
				RAM_CLK 	  <= not RAM_CLK;
				
			end if;
			
			FRAME_COUNTER <= FRAME_COUNTER + 1; -- increase
			OFFSET 		  <= ADDR_COUNTER  - 8; --set the read offset = Write-Offset-8
															--the newest transitions sould appear on the right side of the screen
															--while the renderer renders from left ro right
		end if;
	end process;
	
	--- Instantiate 4kx1Sample buffer
	sample_buffer_inst : entity work.sample_buffer
	port map(
		CLK 				=> CLK,
		RST				=> RST,
		RW  				=> WRITE_EN,
		INPUT 			=> SW, -- Get input directly from Switches for debug
		INPUT_ADDR 		=> ADDR_COUNTER, 
		OUTPUT_ADDR 	=> timeSlot,
		OUTPUT 			=> SAMPLE_BUFFER_OUT
	);
	
	--- Instanciate 800x600x8 VGA controller
	vga_controller_inst : entity work.vga_controller_800_60
	port map(
		PIXEL_CLK 		=> CLKFX_40Mhz,
		RST 				=> RST,
		HS 				=> HSYNC,
		VS 				=> VSYNC,
		HCOUNT 			=> HCOUNT,
		VCOUNT 		 	=> VCOUNT,
		BLANK 			=> BLANK
	);

	--- Instantiate DCM
   -- Xilinx HDL Language Template, version 13.3
   DCM_SP_inst : DCM_SP
   generic map (
      CLKDV_DIVIDE 		 	 => 2.0, 	--  Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
													--     7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
      CLKFX_DIVIDE 		 	 => 5,   	--  Can be any interger from 1 to 32
      CLKFX_MULTIPLY 	 	 => 4, 		--  Can be any integer from 1 to 32
      CLKIN_DIVIDE_BY_2  	 => FALSE,  --  TRUE/FALSE to enable CLKIN divide by two feature
      CLKIN_PERIOD 		 	 => 2000.0, --  Specify period of input clock
      CLKOUT_PHASE_SHIFT 	 => "NONE", --  Specify phase shift of "NONE", "FIXED" or "VARIABLE" 
      CLK_FEEDBACK 			 => "NONE", --  Specify clock feedback of "NONE", "1X" or "2X" 
      DESKEW_ADJUST 		 	 => "SYSTEM_SYNCHRONOUS", -- "SOURCE_SYNCHRONOUS", "SYSTEM_SYNCHRONOUS" or
                                       --     an integer from 0 to 15
      DLL_FREQUENCY_MODE    => "LOW",  -- "HIGH" or "LOW" frequency mode for DLL
      DUTY_CYCLE_CORRECTION => TRUE,   --  Duty cycle correction, TRUE or FALSE
      PHASE_SHIFT 			 => 0,      --  Amount of fixed phase shift from -255 to 255
      STARTUP_WAIT 			 => FALSE)  --  Delay configuration DONE until DCM_SP LOCK, TRUE/FALSE
   port map (
      CLKFX 	=> CLKFX_40Mhz,   -- DCM CLK synthesis out (M/D)
      CLKFB 	=> '0',   -- DCM clock feedback
      CLKIN 	=> CLK,   -- Clock input (from IBUFG, BUFG or DCM)
      PSCLK 	=> '0',   -- Dynamic phase adjust clock input
      PSEN 		=> '0',     -- Dynamic phase adjust enable input
      PSINCDEC => '0', -- Dynamic phase adjust increment/decrement
      RST 		=> RST        -- DCM asynchronous reset input
--      CLKFX180 => CLKFX180, -- 180 degree CLK synthesis out
--      LOCKED => LOCKED, -- DCM LOCK status output
--      PSDONE => PSDONE, -- Dynamic phase adjust done output
--      STATUS => STATUS, -- 8-bit DCM status bits output
--		  CLK0 => CLK0,     -- 0 degree DCM CLK ouptput
--      CLK180 => CLK180, -- 180 degree DCM CLK output
--      CLK270 => CLK270, -- 270 degree DCM CLK output
--      CLK2X => CLK2X,   -- 2X DCM CLK output
--      CLK2X180 => CLK2X180, -- 2X, 180 degree DCM CLK out
--      CLK90 => CLK90,   -- 90 degree DCM CLK output
--      CLKDV => CLKDV,   -- Divided DCM CLK out (CLKDV_DIVIDE)
   );	
   -- End of DCM_SP_inst instantiation
end Behavioral;

