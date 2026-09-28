library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_all is
    port(
        clk                 : in std_logic;
        rst                 : in std_logic;

        -- SBI interface
        chipselect          : in std_logic;
        wr                  : in std_logic;
        rd                  : in std_logic;
        address             : in std_logic_vector(1 downto 0);       -- "00" (CTRL) -- "01" (STATUS) -- "10" (D_RR) -- "11" (D_wr)
        writedata           : in std_logic_vector(15 downto 0);
        readdata            : out std_logic_vector(15 downto 0);

        -- I2C
        sda                 : inout std_logic;
        scl                 : inout std_logic
    );
end entity i2c_all;

architecture struct of i2c_all is

            -- Interface mellom I2C_REG og I2C_MASTER
            signal start_en            : std_logic;                          -- Commands begin transaction
            signal threebyte_mode      : std_logic;                          -- FSM is busy
            signal rw                  : std_logic;                          -- '0' = write, '1' = read
            signal slave_address       : std_logic_vector(7 downto 0);       -- Data to write
            signal register_address    : std_logic_vector(7 downto 0);       -- Data to write
            signal data_wr             : std_logic_vector(7 downto 0);       -- Data to write
            signal data_rd             : std_logic_vector(7 downto 0);       -- Data read
            signal mode                : std_logic;                          -- '0' = 100kHz, '1' = 400kHz
            signal ack_error           : std_logic;                          -- NACK
            signal busy                : std_logic;                          -- FSM is busy

component i2c_reg
    port(
        clk              : in  std_logic;
        rst              : in  std_logic;
        chipselect       : in  std_logic;
        wr               : in  std_logic;
        rd               : in  std_logic;
        address          : in  std_logic_vector(1 downto 0);
        writedata        : in  std_logic_vector(15 downto 0);
        readdata         : out std_logic_vector(15 downto 0);
        start_en         : out std_logic;
        threebyte_mode   : out std_logic := '0';
        rw               : out std_logic;
        slave_address    : out std_logic_vector(7 downto 0);
        register_address : out std_logic_vector(7 downto 0);
        data_wr          : out std_logic_vector(7 downto 0);
        data_rd          : in  std_logic_vector(7 downto 0);
        mode             : out std_logic := '0';
        ack_error        : in  std_logic;
        busy             : in  std_logic
    );
end component i2c_reg;

component I2C_Master
    generic(
        input_clk  : INTEGER := 50_000_000;
        bus_clk100 : INTEGER := 100_000;
        bus_clk400 : INTEGER := 400_000
    );
    port(
        clk              : in    std_logic;
        rst              : in    std_logic;
        start_en         : in    std_logic;
        threebyte_mode   : in    std_logic;
        rw               : in    std_logic;
        slave_address    : in    std_logic_vector(7 downto 0);
        register_address : in    std_logic_vector(7 downto 0);
        data_wr          : in    std_logic_vector(7 downto 0);
        data_rd          : out   std_logic_vector(7 downto 0);
        mode             : in    std_logic;
        ack_error        : out   std_logic;
        busy             : out   std_logic;
        sda              : inout std_logic;
        scl              : inout std_logic
    );
end component I2C_Master;


begin
i2c_reg_inst : component i2c_reg
    port map(
        clk              => clk,
        rst              => rst,
        chipselect       => chipselect,
        wr               => wr,
        rd               => rd,
        address          => address,
        writedata        => writedata,
        readdata         => readdata,
        start_en         => start_en,
        threebyte_mode   => threebyte_mode,
        rw               => rw,
        slave_address    => slave_address,
        register_address => register_address,
        data_wr          => data_wr,
        data_rd          => data_rd,
        mode             => mode,
        ack_error        => ack_error,
        busy             => busy
    );



I2C_Master_inst : component I2C_Master
    generic map(
        input_clk  => 50000000, -- vhdl do not find declaration of these, so i just typed them manually :)
        bus_clk100 => 100000,
        bus_clk400 => 400000
    )
    port map(
        clk              => clk,
        rst              => rst,
        start_en         => start_en,
        threebyte_mode   => threebyte_mode,
        rw               => rw,
        slave_address    => slave_address,
        register_address => register_address,
        data_wr          => data_wr,
        data_rd          => data_rd,
        mode             => mode,
        ack_error        => ack_error,
        busy             => busy,
        sda              => sda,
        scl              => scl
    );



end architecture struct;
