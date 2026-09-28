library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_reg is
    port(
        clk                 : in std_logic;
        rst                 : in std_logic;

        -- SBI interface
        chipselect          : in std_logic;
        wr                  : in std_logic;
        rd                  : in std_logic;
        address             : in std_logic_vector(1 downto 0);       -- "00" (CTRL) -- "01" (STATUS) -- "10" (D_WR) -- "11" (D_RD)
        writedata           : in std_logic_vector(15 downto 0);
        readdata            : out std_logic_vector(15 downto 0);

        -- Interface mot I2C_MASTER
        start_en            : out  std_logic;                        -- Commands begin transaction
        threebyte_mode      : out std_logic;                  -- '0' = 3 bytes, '1' = 2 bytes
        rw                  : out  std_logic;                        -- '0' = write, '1' = read
        slave_address       : out  std_logic_vector(7 downto 0);     -- Data to write
        register_address    : out  std_logic_vector(7 downto 0);     -- Data to write
        data_wr             : out  std_logic_vector(7 downto 0);     -- Data to write
        data_rd             : in   std_logic_vector(7 downto 0);     -- Data read
        mode                : out  std_logic := '0';                 -- '0' = 100kHz, '1' = 400kHz
        ack_error           : in   std_logic;                        -- NACK, signal
        busy                : in   std_logic
        


    );
end entity i2c_reg;

architecture RTL of i2c_reg is

    signal wr_cnt : integer range 0 to 3 := 0;
    signal previous_writedata : std_logic_vector(15 downto 0) := (OTHERS => '0');
    signal wr_ctrl_strobe   : std_logic := '0';
    signal rd_status_strobe : std_logic := '0';
    signal wr_data_strobe   : std_logic := '0';
    signal rd_data_strobe   : std_logic := '0';
    signal reg_threebyte_mode : std_logic  := '1';
    
begin
    threebyte_mode <= reg_threebyte_mode;
    -- Define register map
    wr_ctrl_strobe   <= '1' when chipselect = '1' and wr = '1' and address = "00" else '0';
    rd_status_strobe <= '1' when chipselect = '1' and rd = '1' and address = "01" else '0';
    rd_data_strobe   <= '1' when chipselect = '1' and rd = '1' and address = "10" else '0';
    wr_data_strobe   <= '1' when chipselect = '1' and wr = '1' and address = "11" else '0';

    -- CTRL
    process(clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_threebyte_mode <= '1';
                mode <= '0';
            else
                if wr_ctrl_strobe = '1' then
                    mode           <= writedata(1);
                    reg_threebyte_mode <= writedata(0);
                end if;
            end if;
        end if;
    end process;

        -- RD status and RD DATA
        process(clk) is
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    readdata <= (others => '0');
                else

                    if    rd_status_strobe = '1' then -- read status register
                        readdata <= x"000" & "00" & ack_error & busy;

                    elsif rd_data_strobe = '1' then -- read data register
                        readdata <= x"00" & data_rd;
                    end if;
                end if;

            end if;
        end process;
    
    -- WR_DATA
    process(clk)
        variable is_new_data      : boolean;
        variable is_slave_address : boolean;
        variable is_register      : boolean;
        variable is_data          : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                data_wr  <= (others => '0');
                slave_address <= (others => '0');
                register_address <= (others => '0');
                rw       <= '0';
                start_en <= '0';
            else
                is_new_data         := (writedata    /= previous_writedata);
                is_slave_address    := (writedata(10) = '1' and writedata(9) = '0' and writedata(8) = '0');
                is_register         := (writedata(10) = '0' and writedata(9) = '1' and writedata(8) = '0');
                is_data             := (writedata(10) = '0' and writedata(9) = '0' and writedata(8) = '1');

                if wr_data_strobe = '1' and is_new_data then -- make sure only triggers on a new wr_data_strobe, in case IOWR from nios 2 lasts several cycles
                        previous_writedata <= writedata;
                        if is_slave_address then
                            slave_address <= writedata(7 downto 0);
                            rw            <= writedata(0);
                            wr_cnt        <= wr_cnt + 1;
                        elsif is_register then
                            register_address <= writedata(7 downto 0);
                            wr_cnt           <= wr_cnt + 1;
                        elsif is_data then
                            data_wr <= writedata(7 downto 0);
                            wr_cnt  <= wr_cnt + 1;
                        end if;
                    end if;
                end if;

                if reg_threebyte_mode = '1' then  -- Are we sending 3 bytes data at once, or 2 bytes?
                    if wr_cnt = 3 then -- all iowr have been saved, let's start the i2c_master FSM.
                        start_en <= '1';
                        wr_cnt   <= 0;
                    end if;
                else -- two byte mode
                    if wr_cnt = 2 then -- all iowr have been saved, let's start the i2c_master FSM.
                        start_en <= '1';
                        wr_cnt   <= 0;
                    end if;
                end if;

                if busy = '1' then -- reset start signal once the fsm has started
                    start_en <= '0';
                end if;
        end if;
    end process;
    
end architecture RTL;