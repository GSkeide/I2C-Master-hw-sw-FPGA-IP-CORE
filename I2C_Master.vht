-- Copyright (C) 2024  Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions 
-- and other software and tools, and any partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License 
-- Subscription Agreement, the Intel Quartus Prime License Agreement,
-- the Intel FPGA IP License Agreement, or other applicable license
-- agreement, including, without limitation, that your use is for
-- the sole purpose of programming logic devices manufactured by
-- Intel and sold by Intel or its authorized distributors.  Please
-- refer to the applicable agreement for further details, at
-- https://fpgasoftware.intel.com/eula.

-- ***************************************************************************
-- This file contains a Vhdl test bench template that is freely editable to   
-- suit user's needs .Comments are provided in each section to help the user  
-- fill out necessary details.                                                
-- ***************************************************************************
-- Generated on "05/08/2025 18:35:27"
                                                            
-- Vhdl Test Bench template for design  :  I2C_Master
-- 
-- Simulation tool : Questa Intel FPGA (VHDL)
-- 

LIBRARY ieee;                                               
USE ieee.std_logic_1164.all;                                

ENTITY I2C_Master_vhd_tst IS
END I2C_Master_vhd_tst;
ARCHITECTURE I2C_Master_arch OF I2C_Master_vhd_tst IS
-- constants   
CONSTANT clk_period : time := 20 ns;          
CONSTANT scl100 : time := 10 us;                                      
-- signals                                                   
SIGNAL ack_error : STD_LOGIC;
SIGNAL busy : STD_LOGIC;
SIGNAL clk : STD_LOGIC;
SIGNAL data_rd : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL data_wr : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL mode : STD_LOGIC;
SIGNAL register_address : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL rst : STD_LOGIC;
SIGNAL rw : STD_LOGIC;
SIGNAL scl : STD_LOGIC;
SIGNAL sda : STD_LOGIC;
SIGNAL slave_address : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL stable_rd_flag : STD_LOGIC;
SIGNAL start_en : STD_LOGIC;
SIGNAL threebyte_mode : STD_LOGIC;
COMPONENT I2C_Master
	PORT (
	ack_error : OUT STD_LOGIC;
	busy : OUT STD_LOGIC;
	clk : IN STD_LOGIC;
	data_rd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	data_wr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	mode : IN STD_LOGIC;
	register_address : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	rst : IN STD_LOGIC;
	rw : IN STD_LOGIC;
	scl : INOUT STD_LOGIC;
	sda : INOUT STD_LOGIC;
	slave_address : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	stable_rd_flag : OUT STD_LOGIC;
	start_en : IN STD_LOGIC;
	threebyte_mode : IN STD_LOGIC
	);
END COMPONENT;
BEGIN
	i1 : I2C_Master
	PORT MAP (
-- list connections between master ports and signals
	ack_error => ack_error,
	busy => busy,
	clk => clk,
	data_rd => data_rd,
	data_wr => data_wr,
	mode => mode,
	register_address => register_address,
	rst => rst,
	rw => rw,
	scl => scl,
	sda => sda,
	slave_address => slave_address,
	stable_rd_flag => stable_rd_flag,
	start_en => start_en,
	threebyte_mode => threebyte_mode
	);

	    -- Clock generator
		clk_process : PROCESS
		BEGIN
			WHILE true LOOP
				clk <= '0';
				WAIT FOR clk_period / 2;
				clk <= '1';
				WAIT FOR clk_period / 2;
			END LOOP;
		END PROCESS;

		stim_proc : PROCESS
		BEGIN
			-- Initial reset
			rst <= '0';
			sda <= 'Z';
	
			-- Stimulus: basic I2C write transaction
			WAIT FOR clk_period*5;
			mode <= '0';                    -- Standard 100kHz mode
			threebyte_mode <= '0';          -- Enable full write
			slave_address <= "10101010";         -- Example address
			register_address <= x"0A";      -- Register address
			data_wr <= x"AB";               -- Data to write
			rw <= '0';                      -- Write operation

			wait for clk_period;
			-- Start transaction
			start_en <= '1';
			wait until busy = '1'; 
			start_en <= '0';
			wait for scl100/2;
			wait for scl100*8;
			sda <= '0';
			wait for scl100;
			sda <= 'Z';
			wait for scl100*8;
			sda <= '0';
			wait for scl100;
			sda <= 'Z';
			wait for scl100*8;
			sda <= '0';
			wait for scl100;
			sda <= 'Z';
			

			WAIT until busy = '0'; -- wait for idle state then start Read operation

			WAIT FOR clk_period*5;
			mode <= '0';                    -- Standard 100kHz mode
			threebyte_mode <= '1';          -- Enable full write
			slave_address <= "10101011";         -- Example address
			register_address <= x"00";      -- Register address
			rw <= '1';                      -- read operation
			wait for clk_period;
			start_en <= '1';
			wait until busy = '1'; 
			start_en <= '0';
			wait for scl100/2;
			wait for scl100*8;
			sda <= '0';
			wait for scl100;
			sda <= 'Z';
			-- Stop simulation
			WAIT;
		END PROCESS;                                         
always : PROCESS                                              
-- optional sensitivity list                                  
-- (        )                                                 
-- variable declarations                                      
BEGIN                                                         
        -- code executes for every event on sensitivity list  
WAIT;                                                        
END PROCESS always;                                          
END I2C_Master_arch;
