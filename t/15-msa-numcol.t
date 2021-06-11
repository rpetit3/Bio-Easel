use strict;
use warnings FATAL => 'all';
use Test::More tests => 23;

BEGIN {
    use_ok( 'Bio::Easel::MSA' ) || print "Bail out!\n";
}

#####################################################################
# We do all tests twice, once reading the MSA read in digital mode, #
# and again reading the MSA in text mode - that's what the big for  #
# loop is for.                                                      #
#####################################################################
my $alnfile = "./t/data/RF00177-3seqs.sto";
my $mode;
my $msa1 = undef;
my $msa2 = undef;
my $outfile = undef;
my $trash = undef;
my ($col1000, $col100, $col10, $col1);

# do all tests with in both digital (mode == 0) and text (mode == 1) modes
for($mode = 0; $mode <= 1; $mode++) { 
  # test new 
  $msa1 = Bio::Easel::MSA->new({
      fileLocation => $alnfile, 
      forceText    => $mode,
  });
  isa_ok($msa1, "Bio::Easel::MSA");

  # test addGC_rf_column_numbers()
  $msa1->addGC_rf_column_numbers();

  # write it out
  $outfile = "./t/data/test-msa.out";
  $msa1->write_msa($outfile, "pfam");

  # read it in
  undef $msa2;
  $msa2 = Bio::Easel::MSA->new({
    fileLocation => $outfile,
    forceText    => $mode,
  });
  isa_ok($msa2, "Bio::Easel::MSA");

  #make sure COL annotation correctly set by addGC_rf_column_numbers()
  open(IN, $outfile);
  $trash     = <IN>; # 1
  $trash     = <IN>; # 2
  $trash     = <IN>; # 3
  $trash     = <IN>; # 4
  $trash     = <IN>; # 5
  $trash     = <IN>; # 6
  $trash     = <IN>; # 7
  $col1000 = <IN>; # 8 
  $col100  = <IN>; # 9 
  $col10   = <IN>; # 10
  $col1    = <IN>; # 11 
  chomp $col1000; 
  chomp $col100; 
  chomp $col10; 
  chomp $col1; 
  is($col1000, "#=GC RFCOLX...           0000000000000.0000.00000000000000000000.00.000..0000.0000000000000000000000.000............000000000.....000000.0.00..............................................................................................................................000.000.0000000.00000000000000000000..00000000000000000..000000000000000000000000000000000000000000..000..000..0000..000..0.00.0.0.00.0000.000........................................................00000.....0000000000000000000000000000000000000000000000000000000000000000000000000000.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.000000000000000000000000000000.00.00000000...0000..000000000000000000000000.000000.00000000.........000000.....0000..000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000.000000000000000000.000000.0000000000000.00000000000.00.000000000000000000000.00000.000000000000000000000000000000000000000000000000000000000000000000000..00000000000000000000000000000000000000.00000000.000.000000000000000.000000000000000000000.000000000.0000.0000..00.0000.0000.000000..0............................0000..000000000000.......000.00000000000000000000000..0000.000000.0000000000000000000000.000000000000000000.000.00000000000000000000000000000000000000000000000.000000000000000.00000............0000001111.11111111111..111111..................................111111....11111111111.1111111111111111111111111111111111111111111111111111.111111111111111111111111111111.11111.....111111.............111..11.11111111111111111111111..111.1111.111111111111111111111111111111111111111111111111111111111111111111111.1111.111111111...1111111111111111111.11111111111.1111111111111111111111111111111111111111111111111111111111111111111111111.111.111111111111111111.11111111111111111111111111111111111111111111.111.111111111111.1.1.1111.1111...1111...1111111.111111111111.11111111111111111111.111.1111111111111.111111111111111111...11.11111111111111", "addGC_rf_column_numbers() properly added 1000 column numbers (mode $mode)");
  is($col100, "#=GC RFCOL.X..           0000000000000.0000.00000000000000000000.00.000..0000.0000000000000000000000.000............000000000.....000000.0.00..............................................................................................................................000.000.0000111.11111111111111111111..11111111111111111..111111111111111111111111111111111111111111..111..111..1111..111..1.11.1.1.22.2222.222........................................................22222.....2222222222222222222222222222222222222222222222222222222222222222222222222222.222222222233333333333333333333333333333333333333333333333333333333333333333333333333333.333333333333333333333334444444.44.44444444...4444..444444444444444444444444.444444.44444444.........444444.....4444..444444444444444444444444444444455555555555555555555555555555555555555555555555555555555555555555555.555555555555555555.555555.5555555566666.66666666666.66.666666666666666666666.66666.666666666666666666666666666666666666666666666666666666667777777777777..77777777777777777777777777777777777777.77777777.777.777777777777777.777777777777777777777.778888888.8888.8888..88.8888.8888.888888..8............................8888..888888888888.......888.88888888888888888888888..8888.888888.8888888888888888999999.999999999999999999.999.99999999999999999999999999999999999999999999999.999999999999999.99999............9999990000.00000000000..000000..................................000000....00000000000.0000000000000000000000000000000000000000000000000000.000000000011111111111111111111.11111.....111111.............111..11.11111111111111111111111..111.1111.111111111111111111111111111111111122222222222222222222222222222222222.2222.222222222...2222222222222222222.22222222222.2222222222222222222222333333333333333333333333333333333333333333333333333.333.333333333333333333.33333333333333333333333333334444444444444444.444.444444444444.4.4.4444.4444...4444...4444444.444444444444.44444444444444444444.444.4444444444444.555555555555555555...55.55555555555555", "addGC_rf_column_numbers() properly added 100 column numbers (mode $mode)");
  is($col10, "#=GC RFCOL..X.           0000000001111.1111.11222222222233333333.33.444..4444.4445555555555666666666.677............777777778.....888888.8.88..............................................................................................................................999.999.9999000.00000001111111111222..22222223333333333..444444444455555555556666666666777777777788..888..888..8899..999..9.99.9.9.00.0000.000........................................................01111.....1111112222222222333333333344444444445555555555666666666677777777778888888888.999999999900000000001111111111222222222233333333334444444444555555555566666666667777777.777888888888899999999990000000.00.01111111...1112..222222222333333333344444.444445.55555555.........566666.....6666..677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666.667777777777888888.888899.9999999900000.00000111111.11.112222222222333333333.34444.444444555555555566666666667777777777888888888899999999990000000000111..11111112222222222333333333344444444445.55555555.566.666666667777777.777888888888899999999.990000000.0001.1111..11.1112.2222.222223..3............................3333..333344444444.......445.55555555566666666667777..7777.778888.8888889999999999000000.000011111111112222.222.22233333333334444444444555555555566666666667777.777777888888888.89999............9999990000.00000011111..111112..................................222222....22233333333.3344444444445555555555666666666677777777778888888888.999999999900000000001111111111.22222.....222223.............333..33.33334444444444555555555..566.6666.666677777777778888888888999999999900000000001111111111222222222233333.3333.344444444...4455555555556666666.66677777777.7788888888889999999999000000000011111111112222222222333333333344444444445.555.555555666666666677.77777777888888888899999999990000000000111111.111.122222222223.3.3.3333.3334...4444...4444455.555555556666.66666677777777778888.888.8889999999999.000000000011111111...11.22222222223333", "addGC_rf_column_numbers() properly added 10 column numbers (mode $mode)");
  is($col1, "#=GC RFCOL...X           1234567890123.4567.89012345678901234567.89.012..3456.7890123456789012345678.901............234567890.....123456.7.89..............................................................................................................................012.345.6789012.34567890123456789012..34567890123456789..012345678901234567890123456789012345678901..234..567..8901..234..5.67.8.9.01.2345.678........................................................90123.....4567890123456789012345678901234567890123456789012345678901234567890123456789.012345678901234567890123456789012345678901234567890123456789012345678901234567890123456.789012345678901234567890123456.78.90123456...7890..123456789012345678901234.567890.12345678.........901234.....5678..901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567.890123456789012345.678901.2345678901234.56789012345.67.890123456789012345678.90123.456789012345678901234567890123456789012345678901234567890123456789012..34567890123456789012345678901234567890.12345678.901.234567890123456.789012345678901234567.890123456.7890.1234..56.7890.1234.567890..1............................2345..678901234567.......890.12345678901234567890123..4567.890123.4567890123456789012345.678901234567890123.456.78901234567890123456789012345678901234567890123.456789012345678.90123............4567890123.45678901234..567890..................................123456....78901234567.8901234567890123456789012345678901234567890123456789.012345678901234567890123456789.01234.....567890.............123..45.67890123456789012345678..901.2345.678901234567890123456789012345678901234567890123456789012345678901234.5678.901234567...8901234567890123456.78901234567.8901234567890123456789012345678901234567890123456789012345678901234567890.123.456789012345678901.23456789012345678901234567890123456789012345.678.901234567890.1.2.3456.7890...1234...5678901.234567890123.45678901234567890123.456.7890123456789.012345678901234567...89.01234567890123", "addGC_rf_column_numbers() properly added 1 column numbers (mode $mode)");
  undef $msa2;
  unlink $outfile;

  # number all columns
  # test addGC_all_column_numbers()
  $msa1->addGC_all_column_numbers();

  # write it out
  $outfile = "./t/data/test-msa.out";
  $msa1->write_msa($outfile, "pfam");

  # read it in
  undef $msa2;
  $msa2 = Bio::Easel::MSA->new({
    fileLocation => $outfile,
    forceText    => $mode,
  });
  isa_ok($msa2, "Bio::Easel::MSA");

  #make sure COL annotation correctly set by addGC_rf_column_numbers()
  open(IN, $outfile);
  $trash     = <IN>; # 1
  $trash     = <IN>; # 2
  $trash     = <IN>; # 3
  $trash     = <IN>; # 4
  $trash     = <IN>; # 5
  $trash     = <IN>; # 6
  $trash     = <IN>; # 7
  $trash     = <IN>; # 8
  $trash     = <IN>; # 9
  $trash     = <IN>; # 10
  $trash     = <IN>; # 11
  $col1000 = <IN>; # 12 
  $col100  = <IN>; # 13
  $col10   = <IN>; # 14
  $col1    = <IN>; # 15 
  chomp $col1000; 
  chomp $col100; 
  chomp $col10; 
  chomp $col1; 

  is($col1000, "#=GC COLX...             000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111", "addGC_all_column_numbers() properly added 1000 column numbers (mode $mode)"); 

  is($col100, "#=GC COL.X..             000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111122222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222223333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444455555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555556666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777788888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888889999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333344444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444445555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666677777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777778888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888999999999999999999999999999999999999999999999999999999999999999999999999999999999", "addGC_all_column_numbers() properly added 100 column numbers (mode $mode)"); 

  is($col10, "#=GC COL..X.             000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778888888888999999999900000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999000000000011111111112222222222333333333344444444445555555555666666666677777777778", "addGC_all_column_numbers() properly added 10 column numbers (mode $mode)"); 

  is($col1, "#=GC COL...X             123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", "addGC_all_column_numbers() properly added 1 column numbers (mode $mode)"); 

  undef $msa2;
  unlink $outfile;
}

