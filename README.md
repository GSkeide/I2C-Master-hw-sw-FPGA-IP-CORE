1.	I2C IP core er en fleksibel og robust løsning for kommunikasjon mellom FPGA og eksterne I2C-kompatible enheter. Modulen implementerer full master-funksjonalitet og støtter både 7-bit og tre-byte adresseringsmodi. Denne modulen kan utføre både lese- og skriveoperasjoner med ekstern I2C-buss, inkludert håndtering av ACK/NACK-signaler, STOP- og START-betingelser, og bitnivå-adressering.
-	Master Modus Kommunikasjon
-	Støtte for standard (2 byte) og utvidede 3 byte skriving. Samt lesing.
-	Handtering av START, REG, STOP og acknowledge signaler
-	Integrert status- og kontrollregister
-	Enkel integrasjon med programvare gjennom minnekartgrensesnitt
-	Støtte for 100khz og 400khz modus

2.	Blokkdiagram:
<img width="945" height="522" alt="image" src="https://github.com/user-attachments/assets/c5ae73e4-e667-4723-a6ea-50c8af81315d" />
<img width="945" height="172" alt="image" src="https://github.com/user-attachments/assets/18a35ba3-6dc2-49db-bb29-31ca6035848c" />

3.	Beskrivelse av innganger og utganger
   <img width="545" height="1411" alt="image" src="https://github.com/user-attachments/assets/691c193c-4c9b-407d-ba34-35654ac60acc" />

4. Internt memory map
   <img width="944" height="211" alt="image" src="https://github.com/user-attachments/assets/e1fab4ae-7183-429c-90fa-8538e4551fea" />


Ctrl – dette er kontrollregisteret. Hvis du ikke skriver til dette registeret, vil det settes til standardverdier, dvs. 100 khz scl-hastighet og tre-byte datamodus.
Bit 0 (tre-byte modus): sett til 0 når du kun vil sende 2 byte (slaveadresse + registeradresse).
Sett til 1 for tre-byte modus, hvor du kan sende de forrige 2 byte samt en ekstra databyte.
Bit 1 (modus): sett til 0 for 100 khz modus, sett til 1 for 400 khz modus.
Status – dette er statusregisteret, her kan du lese statusen til i2c-modulen.
Bit 0 (busy) – returnerer 1 hvis i2c for øyeblikket går gjennom en fsm-løkke. Returnerer 0 hvis den er klar for nye kommandoer. Du bør forsikre deg om at denne biten er 0 før du gir en ny kommando for å sikre at det fungerer som det skal. Hvis ikke, kan det fungere, men det gis ingen garantier.
Bit 1 (ack_error) – returnerer 1 hvis mottakeren ikke bekreftet overføringen. Dette vil være en svært kort puls som varer ca. 30 µs ved 100 khz scl-hastighet. Jeg anbefaler ikke å sjekke for denne feilen i c-kode på grunn av hvor kort pulsen er.
D_rd – dette er registeret hvor leste data fra slavene vises. Dette er et skrivebeskyttet register.
D_wr – dette er registeret du skriver til. Hver skriving har en tildelt bit for å sikre at ingen duplikater sendes av avalon-grensesnittet over flere klokkesykluser.
Disse er bit 10–8: start-bit skal settes til 1 når du skriver slaveadressen. Reg skal settes når du skriver den andre byten, og stop skal settes for den siste byten du skriver.
Avhengig av hvilken modus du har valgt i ctrl-registeret, kan du ha enten 2 eller 3 byte. Hvis du skriver 2 byte, spiller det egentlig ingen rolle hvilken rekkefølge du sender den andre byten i, så lenge slaveadressen er tildelt bit 10 = 1, og at hver skriving har én tildelt bit blant bit 10–8.
Aldri ha 2 eller flere av disse bitene satt i én skriving, da modulen vil ignorere skrivingen.
Når du skriver slaveadressen, vil bit 0 angi om kommandoen er en skrive- eller leseoperasjon.
0 = skriv, 1 = les.




5. 	Funksjonell beskrivelse
Modulen opererer ut fra en tilstandsautomat (FSM) som styrer prosessen fra inaktiv (IDLE) til start av kommunikasjon (S_ADDRESS), videre gjennom lese (I2CREAD) eller skriveoperasjoner (REGWRITE, DATAWRITE). ACK-signaler fra slave-enheter avgjør flyten i kommunikasjonen, med håndtering av feiltilstander og STOP-kommando.

<img width="735" height="1005" alt="image" src="https://github.com/user-attachments/assets/c080a941-cb64-4621-aa73-877f1368d0db" />

6.	Timing
Dette avsnittet beskriver de tidsmessige egenskapene til I2C-modulen, både når det gjelder leverte signaler og krav til inngangssignaler. Alle tidspunkter er basert på en systemklokke på 50 MHz (20 ns per syklus).
Generell informasjon:
•	Systemklokke (clock_50): 50 MHz (20 ns periode)
•	Støttede SCL-hastigheter: 100 kHz og 400 kHz
•	I2C spesifikasjoner følges for både Standard Mode (100 kHz) og Fast Mode (400 kHz)
<img width="631" height="572" alt="image" src="https://github.com/user-attachments/assets/dd2d8ad9-ceb4-48ad-b372-e605e768e5e1" />

Test 1 : Timing diagram funksjonalitet test, 3 Bytes sendes, så sendes en Read command

<img width="1008" height="215" alt="image" src="https://github.com/user-attachments/assets/23e07cf0-240b-4b42-a3e4-085f0da5cc3b" />

Test 2 : Timing diagram, 2 Bytes sendes, så en Read command. Dette er hvordan du ville lest et register, i.e ved å sende rtc addressen, rtc register addressen, så sendt en read command.
<img width="1013" height="215" alt="image" src="https://github.com/user-attachments/assets/008d0f2d-a604-46a2-9fdb-7294a4414642" />

Test 3 : Sending av 2 bytes med 400 khz SCL modus:

<img width="944" height="263" alt="image" src="https://github.com/user-attachments/assets/7a42543f-abb2-48cb-991f-ee82348fed2e" />


