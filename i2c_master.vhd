library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity I2C_Master is
    GENERIC(
    input_clk           : INTEGER := 50_000_000;                -- input clock speed from user logic in Hz (CLOCK_50)
    bus_clk100          : INTEGER := 100_000;                   -- speed the i2c bus (scl) will run at in Hz
    bus_clk400          : INTEGER := 400_000);                  -- speed the i2c bus (scl) will run at in Hz
  port (
    clk                 : in  std_logic;
    rst                 : in  std_logic;

    -- Interface mot i2c_reg
    start_en            : in  std_logic;                        -- Commands begin transaction
    threebyte_mode      : in std_logic;
    rw                  : in  std_logic;                        -- '0' = write, '1' = read
    slave_address       : in  std_logic_vector(7 downto 0);     -- Data to write
    register_address    : in  std_logic_vector(7 downto 0);     -- Data to write
    data_wr             : in  std_logic_vector(7 downto 0);     -- Data to write
    data_rd             : out std_logic_vector(7 downto 0);     -- Data read
    mode                : in  std_logic;                        -- '0' = 100kHz, '1' = 400kHz
    ack_error           : out std_logic;                        -- NACK, signal
    busy                : out std_logic;

    -- I2C
    sda                 : inout std_logic;
    scl                 : inout std_logic
  );
end entity;

architecture rtl of I2C_Master is
  -- Divider constants for half-period count
  constant DIV100       : integer := (input_clk/bus_clk100)/4;
  constant DIV400       : integer := (input_clk/bus_clk400)/4;

  -- Internal Signals
  signal count          : integer range 0 to DIV100*4 := 0;     -- for clk gen
  signal scl_clk        : std_logic := '1';                     -- Internal clk for SCL
  signal scl_low        : std_logic := '0';                     -- Kindof "rising-edge" but happens in the middle of when SCL is low
  signal scl_high       : std_logic := '0';                     -- Kindof "rising-edge" but happens in the middle of when SCL is high
  signal scl_enable     : std_logic := '0';                     -- Enables SCL, SCL will always be 'Z' when this is '0'  
  signal slav_address   : std_logic_vector(7 downto 0);         -- Data_wr will be stored here
  signal reg_address    : std_logic_vector(7 downto 0);         -- Data_wr will be stored here
  signal data_tx        : std_logic_vector(7 downto 0);         -- Data_wr will be stored here
  SIGNAL stretch        : STD_LOGIC := '0';                     -- identifies if slave is stretching SCL
  signal timing_flag    : std_logic := '0';                    -- "flag" used to ensure proper fsm timing between scl_low and scl_high

  -- SDA control
  signal sda_out        : std_logic := '1';                     -- 
  signal sda_oe         : std_logic := '0';                     -- '1' = drive SDA

  -- FSM states
  type state_type is (IDLE, START, S_ADDRESS, SLAVE_ACK, REGWRITE, REGACK, DATAWRITE, TXACK, I2CREAD, MASTER_ACK, STOP);
  signal state          : state_type := IDLE;
  signal bit_cnt        : integer range 0 to 7 := 7;

begin
    gen_scl: process(clk, rst)
    begin
      if rst = '1' then
        stretch <= '0';
        count  <= 0;
        scl_clk    <= '1';
        scl_low <= '0';
        scl_high <= '0';
      elsif rising_edge(clk) then
        IF(stretch = '0') THEN                      -- only generate clock if slave is not holding/stretching
                count <= count + 1;
        END IF;

-- Using two identical case statement because that lets us keep div100/div400 as constants which does not produce timing SLACK
-- setting the values of SCL_CLK:
if mode = '0' then

    CASE count IS
    WHEN 0 TO div100-1 =>                           -- first 1/4 cycle of clocking
      scl_clk <= '0';
    WHEN div100 TO div100*2-1 =>                    -- second 1/4 cycle of clocking
      scl_clk <= '0';
    WHEN div100*2 TO div100*3-1 =>                  -- third 1/4 cycle of clocking
        scl_clk <= '1';
        IF(scl = '0' and scl_enable = '1') THEN     -- detect if slave is stretching clock
            stretch <= '1';
        ELSE
            stretch <= '0';
        END IF;
    WHEN OTHERS =>                                  --  last  1/4 cycle of clocking
        scl_clk <= '1';
    END CASE;

    IF (count = div100-1) then
        scl_low  <= '1';                            -- we can change sda when scl_low = 1
    ELSIF (count = div100*3-1) then
        scl_high <= '1';                            -- we can read sda (acks) when scl_high = 1
    ELSIF (count = div100*4-1) THEN                 -- end of timing cycle
        count    <= 0;                              -- reset timer
    ELSE 
        scl_low  <= '0';
        scl_high <= '0';
    end if;

elsif mode = '1' then

    CASE count IS
    WHEN 0 TO div400-1 =>                           -- first 1/4 cycle of clocking
      scl_clk   <= '0';
    WHEN div400 TO div400*2-1 =>                    -- second 1/4 cycle of clocking
      scl_clk   <= '0';
    WHEN div400*2 TO div400*3-1 =>                  -- third 1/4 cycle of clocking
        scl_clk <= '1';
        IF(scl = '0' and scl_enable = '1') THEN     -- detect if slave is stretching clock
            stretch <= '1';
        ELSE
            stretch <= '0';
        END IF;
    WHEN OTHERS =>                                  --  last  1/4 cycle of clocking
        scl_clk <= '1';
END CASE;

    IF (count = div400-1) then
        scl_low  <= '1';                            -- we can change sda when scl_low = 1
    ELSIF (count = div400*3-1) then
        scl_high <= '1';                            -- we can read sda (acks) when scl_high = 1
    ELSIF(count = div400*4-1) THEN                  -- end of timing cycle
        count    <= 0;                              -- reset timer
    ELSE 
        scl_low  <= '0';
        scl_high <= '0';
    end if;

end if;
    END IF;
END PROCESS;


  fsm: process(clk)
  begin
    if rising_edge(clk) then
    if rst = '1' then
      state       <= IDLE;
      busy        <= '0';
      reg_address <= (others => '0');
      slav_address<= (others => '0');
      ack_error   <= '0';
      data_rd     <= (others => '0');
      sda_out     <= '1';
      sda_oe      <= '0';
      bit_cnt     <= 7;
      data_tx     <= (others => '0');
      timing_flag <= '0';
      scl_enable <= '0';
    else

            case state is
            when IDLE =>
                busy           <= '0';
                sda_oe         <= '0';
                sda_out        <= '1';
                ack_error <= '0';
                if (scl_low = '1') then                     -- The "middle" of when SCL is low.
                    if start_en = '1' then                  -- Once SBI sends a start signal, run
                    slav_address    <= slave_address;       -- save data to write
                    reg_address     <= register_address;    -- save data to write
                    data_tx         <= data_wr;             -- save data to write
                    bit_cnt         <= 7;                   -- set bit_cnt to 7 
                    state           <= START;
                    else 
                        state       <= IDLE;
                    end if; 
                end if;
                if (scl_high = '1') then                    -- Nothing
                end if;

            when START =>
                if (scl_low = '1') then                     -- Nothing
                end if;
                if (scl_high = '1') then                    -- When scl HIGH (middle, not r ising edge)
                    busy       <= '1';                      -- FSM is busy
                    scl_enable <= '1';                      -- Enable output of internal SCL to SCL bidir
                    sda_oe     <= '1';                      -- Enable writing to SDA bidir
                    sda_out    <= '0';                      -- Drive SDA low while scl is HIGH (start-pulse)¨
                    state <= S_ADDRESS;
                end if;

            when S_ADDRESS =>
                if (scl_low = '1') then -- LOW
                    sda_oe    <= '1';                   -- Enable SDA writing
                    sda_out <= slav_address(bit_cnt);
                    IF(bit_cnt = 0) THEN                    -- done counting
                        bit_cnt <= 7;                       -- reset bit_cnt
                        state   <= SLAVE_ACK;         
                    ELSE                                    -- counting from 7
                        bit_cnt <= bit_cnt - 1;             
                    END IF;
                end if;
                if (scl_high = '1') then -- HIGH
                end if;

                when SLAVE_ACK =>
                    if (scl_low = '1') then -- LOW
                        sda_oe      <= '0';                 -- tristate 
                        timing_flag <= '1';                 -- makes sure scl_low is run before scl_high to ensure proper timing
                    end if;
                    if (scl_high = '1' and timing_flag = '1') then -- HIGH
                        timing_flag <= '0';
                        if sda = '0' then                   -- Read for ACK
                            if rw = '0' then                -- Send to WR
                                state     <= REGWRITE;
                            else                           -- Send to RD
                                state     <= I2CREAD;
                            end if;
                         else                               -- Detect NACK
                             ack_error     <= '1';          -- error flag
                             state         <= stop;
                         end if;
                    end if;

                when REGWRITE =>
                    if (scl_low = '1') then -- LOW                     
                        sda_oe    <= '1';                   -- Enable SDA writing
                        sda_out   <= REG_ADDRESS(bit_cnt);      -- Set values of SDA to stored data_wr
                        if bit_cnt = 0 then                 -- Done counting
                          bit_cnt <= 7;                     -- Reset counter
                          state   <= REGACK;
                        else                                -- Count from 7
                          bit_cnt <= bit_cnt - 1; 
                        end if;
                    end if;
                    if (scl_high = '1') then -- HIGH
                    end if;

                when REGACK =>
                    if (scl_low = '1') then -- LOW
                        sda_oe <= '0';                      -- tristate SDA
                        timing_flag <= '1';                 -- makes sure scl_low is run before scl_high to ensure proper timing
                    end if;
                    if (scl_high = '1' and timing_flag = '1') then -- HIGH
                        timing_flag <= '0';
                        if sda = '0' then                   -- Read for ACK
                            if threebyte_mode = '1' then
                                state <= DATAWRITE;
                            else -- twobyte_mode
                                state <= STOP;
                            end if;
                        else
                            ack_error <= '1';               -- NACK detected
                            state     <= stop;
                        end if;
                    end if;

                when DATAWRITE =>
                    if (scl_low = '1') then -- LOW                    
                        sda_oe    <= '1';                   -- Enable SDA writing
                        sda_out   <= data_tx(bit_cnt);      -- Set values of SDA to stored data_wr
                        if bit_cnt = 0 then                 -- Done counting
                          bit_cnt <= 7;                     -- Reset counter
                          state   <= TXACK;
                        else                                -- Count from 7
                          bit_cnt <= bit_cnt - 1; 
                        end if;
                    end if;
                    if (scl_high = '1') then -- HIGH
                    end if;

                when TXACK =>
                    if (scl_low = '1') then -- LOW
                        sda_oe <= '0';                      -- tristate SDA
                        timing_flag <= '1';                 -- makes sure scl_low is run before scl_high to ensure proper timing
                    end if;
                    if (scl_high = '1' and timing_flag = '1') then -- HIGH
                        timing_flag <= '0';
                        if sda = '0' then                   -- Read for ACK
                            state     <= STOP;
                        else
                            ack_error <= '1';               -- NACK detected
                            state     <= STOP;
                        end if;
                    end if;


                when I2CREAD =>
                    if (scl_low = '1') then -- LOW
                        timing_flag    <= '1';              -- makes sure scl_low is run before scl_high to ensure proper timing
                        sda_oe         <= '0';              -- tristate
                    end if;
                    if (scl_high = '1' and timing_flag = '1') then -- HIGH
                        timing_flag <= '0';
                        data_rd(bit_cnt) <= sda;
                        IF(bit_cnt = 0) THEN
                            bit_cnt <= 7;
                            state   <= master_ack;
                          ELSE
                            bit_cnt <= bit_cnt - 1;
                          END IF;   
                    end if;
                
                when MASTER_ACK =>
                    if (scl_low = '1') then -- LOW
                        sda_oe <= '0';                     -- tristate/nack as we only want one data
                        state  <= STOP;
                    end if;
                    if (scl_high = '1') then -- HIGH
                    end if;

                when STOP =>
                    if (scl_low = '1') then -- LOW
                        timing_flag    <= '1';              -- makes sure scl_low is run before scl_high to ensure proper timing
                        sda_out        <= '0'; 
                        sda_oe         <= '1';
                    end if;
                    if (scl_high = '1' and timing_flag = '1') then -- HIGH
                        timing_flag    <= '0';
                        scl_enable     <= '0';              -- tristate SCL
                        sda_oe         <= '0';              -- tristate SDA
                        sda_out        <= '1';              -- tristate SDA  
                        state          <= IDLE;
                    end if;
            end case;
    end if;
    end if;
  end process; 
  scl <= '0' when (scl_clk = '0' and scl_enable = '1')  else 'Z'; 
  sda <= '0' when (sda_out = '0' and sda_oe = '1') else 'Z';

end architecture;