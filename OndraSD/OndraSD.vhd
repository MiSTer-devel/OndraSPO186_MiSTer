library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.zpupkg.ALL;

entity OndraSD is
	generic (
		sysclk_frequency : integer := 50000000 -- 50MHz
	);
	port (
   
      clk         : in std_logic;
      reset_in    : in std_logic;
      enter_key   : in std_logic;
      signal_led  : out std_logic := '1';

		-- SPI signals
		spi_miso		: in std_logic := '1'; -- Allow the SPI interface not to be plumbed in.
		spi_mosi		: out std_logic;
		spi_clk		: out std_logic;
		spi_cs      : out std_logic;      

		-- UART
		rxd	: in std_logic;
		txd	: out std_logic

); 
end entity;


architecture rtl of OndraSD is

--constant maxAddrBit : integer := 13;
constant maxAddrBit : integer := 31;

--constant uart_divisor_9600  : integer := 50000000/9600;
constant uart_divisor_9600  : integer := 50000000/9600;
constant uart_divisor_57600 : integer := 50000000/57600;

signal uart_divisor : integer := uart_divisor_9600; 
   
signal enter_key_pressed_set : std_logic;
signal enter_key_pressed_reset : std_logic;
signal enter_key_pressed : std_logic; 


    
signal reset : std_logic := '0';
signal reset_counter : unsigned(15 downto 0) := X"FFFF";
 

-- Millisecond counter
signal millisecond_counter : unsigned(31 downto 0) := X"00000000";
signal millisecond_tick : unsigned(19 downto 0);
   
-- SPI Clock counter
signal spi_tick : unsigned(8 downto 0);
signal spiclk_in : std_logic;
signal spi_fast : std_logic;

-- SPI signals
signal host_to_spi : std_logic_vector(7 downto 0);
signal spi_to_host : std_logic_vector(31 downto 0);
signal spi_wide : std_logic;
signal spi_trigger : std_logic;
signal spi_busy : std_logic;
signal spi_active : std_logic;

-- UART signals

signal ser_txdata : std_logic_vector(7 downto 0);
signal ser_txready : std_logic;
signal ser_rxdata : std_logic_vector(7 downto 0);
signal ser_rxrecv : std_logic;
signal ser_txgo : std_logic;
signal ser_rxint : std_logic;

-- ZPU signals

signal mem_busy           : std_logic;
signal mem_read             : std_logic_vector(wordSize-1 downto 0);
signal mem_write            : std_logic_vector(wordSize-1 downto 0);
signal mem_addr             : std_logic_vector(MaxAddrBit downto 0);

signal mem_writeEnable      : std_logic; 
signal mem_writeEnableh      : std_logic; 
signal mem_writeEnableb      : std_logic; 
signal mem_readEnable       : std_logic;

 
-- Timer register block signals
signal timer_reg_req : std_logic;
signal timer_tick : std_logic;

signal zpu_to_rom : ZPU_ToROM;
signal zpu_from_rom : ZPU_FromROM;

begin

enter_key_pressed_set <= enter_key;

-- Reset counter.

process(clk)
begin
	if reset_in='0' then
		reset_counter<=X"FFFF";
		reset<='0';
	elsif rising_edge(clk) then
		reset_counter<=reset_counter-1;
		if reset_counter=X"0000" then
			reset<='1';
		end if;
	end if;
end process;

-- processing Enter Key Pressed info
process(clk)
begin   
   if enter_key_pressed_reset='1' then
      enter_key_pressed<='0';      
   elsif enter_key='1' then
      enter_key_pressed<='1';
   end if;   
end process;


-- Timer
process(clk)
begin
	if rising_edge(clk) then
		millisecond_tick<=millisecond_tick+1;
		--if millisecond_tick=sysclk_frequency*100 then
      if millisecond_tick=(50000) then -- 1/1000 * 50 000 000 ??
			millisecond_counter<=millisecond_counter+1;
			millisecond_tick<=X"00000";
		end if;
	end if;
end process;

-- SPI Timer
process(clk)
begin
	if rising_edge(clk) then
		spiclk_in<='0';
		spi_tick<=spi_tick+1;
		if (spi_fast='1' and spi_tick(5)='1') or spi_tick(8)='1' then
			spiclk_in<='1'; -- Momentary pulse for SPI host.
			spi_tick<='0'&X"00";
		end if;
	end if;
end process;

-- SPI host
spi : entity work.spi_interface
	port map(
		sysclk => clk,
		reset => reset,

		-- Host interface
		spiclk_in => spiclk_in,
		host_to_spi => host_to_spi,
		spi_to_host => spi_to_host,
		trigger => spi_trigger,
		busy => spi_busy,

		-- Hardware interface
		miso => spi_miso,
		mosi => spi_mosi,
		spiclk_out => spi_clk
	);
 

-- UART

myuart : entity work.simple_uart
	generic map(
		enable_tx=>true,
		enable_rx=>true
	)
	port map(
		clk => clk,
		reset => reset, -- active low
		txdata => ser_txdata,
		txready => ser_txready,
		txgo => ser_txgo,
		rxdata => ser_rxdata,
		rxint => ser_rxint,
		txint => open,
		clock_divisor => to_unsigned(uart_divisor,16),
		rxd => rxd,
		txd => txd
	);


-- OndraSD ROM

	myrom : entity work.OndraSD_ZPU_ROM
	generic map
	(
		maxAddrBitBRAM => 14
	)
	port map (
		clk => clk,
		from_zpu => zpu_to_rom,
		to_zpu => zpu_from_rom
	);

 
-- Main CPU

	zpu: zpu_core_flex
	generic map (
		IMPL_MULTIPLY => false,
		IMPL_COMPARISON_SUB => false,
		IMPL_EQBRANCH => false,
		IMPL_STOREBH => false,
		IMPL_LOADBH => false,
		IMPL_CALL => false,
		IMPL_SHIFT => false,
		IMPL_XOR => false,
		REMAP_STACK => false,
		EXECUTE_RAM => false,
       
--		IMPL_MULTIPLY => true,
--		IMPL_COMPARISON_SUB => true,
--		IMPL_EQBRANCH => true,
--		IMPL_STOREBH => true,
--		IMPL_LOADBH => true,
--		IMPL_CALL => true,
--		IMPL_SHIFT => true,
--		IMPL_XOR => true,
--		CACHE => false,
----		IMPL_EMULATION => minimal,
--		REMAP_STACK => false, -- We need to remap the Boot ROM / Stack RAM so we can access SDRAM
--		EXECUTE_RAM => false, -- We might need to execute code from SDRAM, too.
----                   
		maxAddrBitBRAM => 14,
		maxAddrBit => maxAddrBit 
	) 
	port map (
		clk                 => clk,
		reset               => not reset,
		in_mem_busy         => mem_busy,
		mem_read            => mem_read,
		mem_write           => mem_write,
		out_mem_addr        => mem_addr,
		out_mem_writeEnable => mem_writeEnable,
		out_mem_hEnable     => mem_writeEnableh,
		out_mem_bEnable     => mem_writeEnableb,
		out_mem_readEnable  => mem_readEnable,
		from_rom => zpu_from_rom,
		to_rom => zpu_to_rom
	);


process(clk)
begin
	if reset='0' then
		spi_cs<='1';
		spi_active<='0';      
      uart_divisor<=uart_divisor_9600; 
	elsif rising_edge(clk) then
		mem_busy<='1';
		ser_txgo<='0';
		spi_trigger<='0';
		timer_reg_req<='0';

		-- Write from CPU?
		if mem_writeEnable='1' then
			case mem_addr(31)&mem_addr(10 downto 8) is

				when X"F" =>	-- Peripherals at 0xFFFFFFF00
					case mem_addr(7 downto 0) is
                      
						when X"A0" => -- Signal LED
							signal_led<=mem_write(0);
	 						mem_busy<='0';

						when X"A4" => -- UART speed
                     IF (mem_write(0)='0') THEN
                        uart_divisor <= uart_divisor_9600;
                     ELSE
                        uart_divisor <= uart_divisor_57600;
                     END IF;
							mem_busy<='0';

						when X"C0" => -- UART
							ser_txdata<=mem_write(7 downto 0);
							ser_txgo<='1';                     
							mem_busy<='0';
                     
						when X"D0" => -- SPI CS
							spi_cs<=not mem_write(0);                     
							spi_fast<=mem_write(8);
							mem_busy<='0';

						when X"D4" => -- SPI Data
							spi_wide<='0';
							spi_trigger<='1';
							host_to_spi<=mem_write(7 downto 0);
							spi_active<='1';
						
						when X"D8" => -- SPI Pump (32-bit read)
							spi_wide<='1';
							spi_trigger<='1';
							host_to_spi<=mem_write(7 downto 0);
							spi_active<='1';

						when others =>
							mem_busy<='0';
							null;
					end case;
				when others =>
                     mem_busy<='0';
							null;
			end case;

		elsif mem_readEnable='1' then -- Read from CPU?
      
			enter_key_pressed_reset<='0';
			case mem_addr(31)&mem_addr(10 downto 8) is

				when X"F" =>	-- Peripherals
					case mem_addr(7 downto 0) is
						when X"A8" => -- Enter Key Pressed
							mem_read<=(others=>'X');
							mem_read(0)<=enter_key_pressed;		
							enter_key_pressed_reset<=enter_key_pressed; -- reset only if it was pressed
	 						mem_busy<='0';

						when X"C0" => -- UART
							mem_read<=(others=>'X');
							mem_read(9 downto 0)<=ser_rxrecv&ser_txready&ser_rxdata;
							ser_rxrecv<='0';	-- Clear rx flag.
							mem_busy<='0';
							
						when X"C8" => -- Millisecond counter
							mem_read<=std_logic_vector(millisecond_counter);
							mem_busy<='0';

						when X"D0" => -- SPI Status
							mem_read<=(others=>'X');
							mem_read(15)<=spi_busy;
							mem_busy<='0';

						when X"D4" => -- SPI read (blocking)
							spi_active<='1';

						when X"D8" => -- SPI wide read (blocking)
							spi_wide<='1';
							spi_trigger<='1';
							spi_active<='1';
							host_to_spi<=X"FF";

						when others =>
							mem_busy<='0';
							null;
					end case;

				when others => 
                     mem_busy<='0';
							null;
			end case;
		end if;

	-- SPI cycles

	if spi_active='1' and spi_busy='0' then
		mem_read<=spi_to_host;
		spi_active<='0';
		mem_busy<='0';
	end if;


		-- Set this after the read operation has potentially cleared it.
		if ser_rxint='1' then
			ser_rxrecv<='1';
		end if;
 
	end if; -- rising-edge(clk)
 
end process;
	
end architecture;
