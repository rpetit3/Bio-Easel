package Bio::Easel::MSA;

use strict;
use warnings;
use File::Spec;
use Carp;

=head1 NAME

Bio::Easel - The great new Bio::Easel!

=head1 VERSION

Version 0.01

=cut

#-------------------------------------------------------------------------------

our $VERSION = '0.01';

# Easel status codes, these must be consistent with #define's in Bio-Easel/src/easel/easel.h
our $ESLOK             = '0';     # no error/success
our $ESLFAIL           = '1';     # failure
our $ESLEOL            = '2';     # end-of-line (often normal)
our $ESLEOF            = '3';     # end-of-file (often normal)
our $ESLEOD            = '4';     # end-of-data (often normal)
our $ESLEMEM           = '5';     # malloc or realloc failed
our $ESLENOTFOUND      = '6';     # file or key not found
our $ESLEFORMAT        = '7';     # file format not correct
our $ESLEAMBIGUOUS     = '8';     # an ambiguity of some sort
our $ESLEDIVZERO       = '9';     # attempted div by zero
our $ESLEINCOMPAT      = '10';    # incompatible parameters
our $ESLEINVAL         = '11';    # invalid argument/parameter
our $ESLESYS           = '12';    # generic system call failure
our $ESLECORRUPT       = '13';    # unexpected data corruption
our $ESLEINCONCEIVABLE = '14';    # "can't happen" error
our $ESLESYNTAX        = '15';    # invalid user input syntax
our $ESLERANGE         = '16';    # value out of allowed range
our $ESLEDUP           = '17';    # saw a duplicate of something
our $ESLENOHALT        = '18';    # a failure to converge
our $ESLENORESULT      = '19';    # no result was obtained
our $ESLENODATA        = '20';    # no data provided, file empty
our $ESLETYPE          = '21';    # invalid type of argument
our $ESLEOVERWRITE     = '22';    # attempted to overwrite data
our $ESLENOSPACE       = '23';    # ran out of some resource
our $ESLEUNIMPLEMENTED = '24';    # feature is unimplemented
our $ESLENOFORMAT      = '25';    # couldn't guess file format
our $ESLENOALPHABET    = '26';    # couldn't guess seq alphabet
our $ESLEWRITE         = '27';    # write failed (fprintf, etc)

my $src_file      = undef;
my $typemaps      = undef;
my $easel_src_dir = undef;

BEGIN {
  $src_file = __FILE__;
  $src_file =~ s/\.pm/\.c/;

  $easel_src_dir = File::Spec->catfile( $ENV{BIO_EASEL_SHARE_DIR}, 'src/easel' );

  $typemaps = __FILE__;
  $typemaps =~ s/\.pm/\.typemap/;
}

use Inline
  C        => "$src_file",
  VERSION  => '0.01',
  ENABLE   => 'AUTOWRAP',
  INC      => "-I$easel_src_dir",
  LIBS     => "-L$easel_src_dir -leasel",
  TYPEMAPS => $typemaps,
  NAME     => 'Bio::Easel::MSA';

=head1 SYNOPSIS

Multiple sequence alignment handling through inline C with Easel.

Perhaps a little code snippet.

    use Bio::Easel::MSA;

    my $foo = Bio::Easel::MSA->new({"fileLocation" => $alnfile});
    ...

=head1 EXPORT

No functions currently exported.

=head1 SUBROUTINES/METHODS
=cut

#-------------------------------------------------------------------------------

=head2 new 

  Title    : new
  Incept   : EPN, Thu Jan 24 09:28:54 2013
  Usage    : Bio::Easel::MSA->new
  Function : Generates a new Bio::Easel::MSA object.
           : Either <fileLocation> or <esl_msa> must be passed in.
  Args     : <fileLocation>: optional: file location of alignment
           : <esl_msa>:      optional: ptr to an Easel ESL_MSA object
           : <reqdFormat>:   optional: string defining requested/required format
           :                 valid format strings are: 
           :                 "unknown", "Stockholm", "Pfam", "UCSC A2M", "PSI-BLAST", 
           :                 "SELEX", "aligned FASTA", "Clustal", "Clustal-like", 
           :                 "PHLYIP (interleaved)", or "PHYLIP (sequential)"
           : <forceText>:    '1' to read the alignment in text mode
           : <isRna>:        '1' to force RNA alphabet
           : <isDna>:        '1' to force DNA alphabet
           : <isAmino>:      '1' to force protein alphabet
           :
  Returns  : Bio::Easel::MSA object

=cut

sub new {
  my ( $caller, $args ) = @_;
  my $class = ref($caller) || $caller;
  my $self = {};

  bless( $self, $caller );

  # set flag to digitize, unless forceText passed in
  if ( defined $args->{forceText} && $args->{forceText}) { 
    $self->{digitize} = 0;
  }
  else { 
    $self->{digitize} = 1;
  }

  if ( defined $args->{isRna} ) { 
    $self->{isRna} = $args->{isRna};
  }
  if ( defined $args->{isDna} ) { 
    $self->{isDna} = $args->{isDna};
  }
  if ( defined $args->{isAmino} ) { 
    $self->{isAmino} = $args->{isAmino};
  }

  # First check that the file exists. If it exists, read it with
  # Easel and populate the object from the ESL_MSA object
  if ( defined $args->{fileLocation} && -e $args->{fileLocation} ) {
    eval {
      $self->{path}   = $args->{fileLocation};
      if(defined $args->{reqdFormat}) { 
        $self->{reqdFormat} = $args->{reqdFormat};
        $self->_check_reqd_format();
      }
      $self->read_msa();
    };    # end of eval
    if ($@) {
      if(defined $args->{reqdFormat}) { 
        confess("Error creating ESL_MSA from @{[$args->{fileLocation}]} if code 7 probably wrong format, $@\n");
      }
      else { 
        confess("Error creating ESL_MSA from @{[$args->{fileLocation}]}, $@\n");
      }
    }
  }
  elsif (defined $args->{esl_msa}) { 
    $self->{esl_msa} = $args->{esl_msa};
  }
  else {
    confess("Expected to receive an ESL_MSA or valid file location path (@{[$args->{fileLocation}]} doesn\'t exist)");
  }
  if ( defined $args->{aliType} ) {
    $self->{aliType} = $args->{aliType};
  }
  
  return $self;
}

#-------------------------------------------------------------------------------

=head2 msa

  Title    : msa
  Incept   : EPN, Tue Jan 29 09:06:30 2013
  Usage    : $msaObject->msa()
  Function : Accessor for msa: sets (if nec) and returns MSA.
  Args     : none
  Returns  : msa   

=cut

sub msa {
  my ($self) = @_;

  if ( !defined( $self->{esl_msa} ) ) {
    $self->read_msa();
  }
  return $self->{esl_msa};
}

#-------------------------------------------------------------------------------

=head2 path

  Title    : path
  Incept   : EPN, Tue Jan 30 15:42:30 2013
  Usage    : $msaObject->path()
  Function : Accessor for path, read only.
  Args     : none
  Returns  : string containing path to the SEED or undef.   

=cut

sub path {
  my ($self) = @_;

  return defined( $self->{path} ) ? $self->{path} : undef;
}

#-------------------------------------------------------------------------------

=head2 format

  Title    : format
  Incept   : rdf, Fri Jul 19 14:05:01 2013
  Usage    : $msaObject->format()
  Function : Gets the format of the MSA
  Args     : none
  Returns  : String of the format.

=cut

sub format {
  my ($self) = @_;
  
  if(!$self->{informat}){
    $self->read_msa;
  }

  return ($self->{informat});
}

#-------------------------------------------------------------------------------

=head2 is_digitized

  Title    : is_digitized
  Incept   : EPN, Wed Mar  5 09:14:34 2014
  Usage    : $msaObject->is_digitized()
  Function : Returns '1' is MSA is digitized, else returns '0'
  Args     : none
  Returns  : '1' if MSA is digitized, else returns '0'.

=cut

sub is_digitized {
  my ($self) = @_;
  
  return _c_is_digitized( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 read_msa

  Title    : read_msa
  Incept   : EPN, Mon Jan 28 09:26:24 2013
  Usage    : $msaObject->read_msa($fileLocation)
  Function : Opens $fileLocation, reads first MSA, sets it.
  Args     : <fileLocation>: file location of alignment, required unless $self->{path} already set
           : <reqdFormat>:   optional, required format of alignment file
           : <do_text>:      optional, TRUE to read alignment in text mode
  Returns  : void

=cut

sub read_msa {
  my ( $self, $fileLocation, $reqdFormat, $do_text ) = @_;

  if ($fileLocation) {
    $self->{path} = $fileLocation;
  }
  if ( !defined $self->{path} ) {
    croak "trying to read msa but path is not set";
  }

  if ($reqdFormat) { 
    $self->{reqdFormat} = $reqdFormat;
  }

  # default is to read in digital mode
  if (defined $do_text && $do_text) { 
    $self->{digitize} = 0;
  }
  elsif(! defined $self->{digitize}) { 
    $self->{digitize} = 1; 
  }

  # default is to guess alphabet
  if (! defined $self->{isRna}) { 
    $self->{isRna} = 0;
  }
  if (! defined $self->{isDna}) { 
    $self->{isDna} = 0;
  }
  if (! defined $self->{isAmino}) { 
    $self->{isAmino} = 0;
  }

  my $informat = "unknown";
  if (defined $self->{reqdFormat}) {
    $informat = $self->{reqdFormat};
    $self->_check_reqd_format();
  }

  ($self->{esl_msa}, $self->{informat}) = _c_read_msa( $self->{path}, $informat, $self->{digitize}, $self->{isRna}, $self->{isDna}, $self->{isAmino});
  # Possible values for 'format', a string, derived from esl_msafile.c::esl_msafile_DecodeFormat(): 
  # "unknown", "Stockholm", "Pfam", "UCSC A2M", "PSI-BLAST", "SELEX", "aligned FASTA", "Clustal", 
  # "Clustal-like", "PHYLIP (interleaved)", or "PHYLIP (sequential)".

  return;
}

#-------------------------------------------------------------------------------

=head2 nseq

  Title    : nseq
  Incept   : EPN, Mon Jan 28 09:35:21 2013
  Usage    : $msaObject->nseq()
  Function : Gets number of seqs in MSA
  Args     : none
  Returns  : number of sequences (esl_msa->nseq)

=cut

sub nseq {
  my ($self) = @_;

  $self->_check_msa();
  return _c_nseq( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 alen

  Title    : alen
  Incept   : EPN, Tue Jan 29 07:41:08 2013
  Usage    : $msaObject->alen()
  Function : Get alignment length.
  Args     : none
  Returns  : alignment length, number of columns (esl_msa->alen)

=cut

sub alen {
  my ($self) = @_;

  $self->_check_msa();
  return _c_alen( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 checksum

  Title    : checksum
  Incept   : EPN, Tue Mar  4 09:42:52 2014
  Usage    : $msaObject->checksum()
  Function : Determine the checksum for an MSA. Caution: the 
           : same MSA will give a different checksum depending
           : on whether it was read in text or digital mode.
  Args     : none
  Returns  : checksum as in integer.

=cut

sub checksum {
  my ($self) = @_;

  $self->_check_msa();
  return _c_checksum( $self->{esl_msa} );
}


#-------------------------------------------------------------------------------

=head2 has_rf

  Title    : has_rf
  Incept   : EPN, Tue Apr  2 19:44:21 2013
  Usage    : $msaObject->has_rf()
  Function : Does MSA have RF annotation?
  Args     : none
  Returns  : '1' if MSA has RF annotation, else returns 0

=cut

sub has_rf {
  my ($self) = @_;

  $self->_check_msa();
  return _c_has_rf( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 has_ss_cons

  Title    : has_ss_cons
  Incept   : EPN, Fri May 24 09:56:40 2013
  Usage    : $msaObject->has_ss_cons()
  Function : Does MSA have SS_cons annotation?
  Args     : none
  Returns  : '1' if MSA has SS_cons annotation, else returns 0

=cut

sub has_ss_cons {
  my ($self) = @_;

  $self->_check_msa();
  return _c_has_ss_cons( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 get_rf

  Title    : get_rf
  Incept   : EPN, Thu Nov 21 10:10:00 2013
  Usage    : $msaObject->get_rf()
  Function : Returns msa->rf if it exists, else dies via croak.
  Args     : None
  Returns  : msa->rf if it exists, else dies

=cut

sub get_rf { 
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  if(! $self->has_rf()) { croak "Trying to fetch RF from MSA but it does not exist"; }
  return _c_get_rf( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 get_rflen

  Title     : get_rflen
  Incept    : EPN, Fri Mar 15 15:48:42 2019
  Usage     : $msaObject->rflen
  Function  : Return nongap RF length for the MSA
  Args      : $gapstr: string of characters to consider as gaps,
            :          if undefined we use '.-~'
  Returns   : length of msa->rf after removing gaps, if it exists, else dies
=cut
    
sub get_rflen
{
  my ($self, $gapstr) = @_;

  $self->_check_msa();
  if(! defined $gapstr) { $gapstr = ".-~"; }
  
  if(! $self->has_rf) { croak "Trying to remove RF gap columns, but no RF annotation exists in the MSA"; }
  my $rf = $self->get_rf;
  $rf =~ s/[\Q$gapstr\E]//g;
  return length($rf);
}

#-------------------------------------------------------------------------------

=head2 set_rf

  Title    : set_rf
  Incept   : EPN, Tue Feb 18 09:54:20 2014
  Usage    : $msaObject->set_rf()
  Function : Sets msa->rf given a string.
  Args     : $rfstr: string that will become RF
  Returns  : void
  Dies     : if length($rfstr) != msa->alen

=cut

sub set_rf { 
  my ( $self, $rfstr ) = @_;

  $self->_check_msa();
  if(length($rfstr) != $self->alen) { croak "Trying to set RF with string of incorrect length"; }
  return _c_set_rf( $self->{esl_msa}, $rfstr );
}

#-------------------------------------------------------------------------------

=head2 get_ss_cons

  Title    : get_ss_cons
  Incept   : EPN, Fri May 24 10:03:41 2013
  Usage    : $msaObject->get_ss_cons()
  Function : Returns msa->ss_cons if it exists, else dies via croak.
  Args     : None
  Returns  : msa->ss_cons if it exists, else dies

=cut

sub get_ss_cons { 
  my ( $self ) = @_;

  $self->_check_msa();
  if(! $self->has_ss_cons()) { croak "Trying to fetch SS_cons from MSA but it does not exist"; }
  return _c_get_ss_cons( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 get_ss_cons_dot_parantheses

  Title    : get_ss_cons_dot_parantheses
  Incept   : EPN, Wed May 21 12:01:48 2014
  Usage    : $msaObject->get_ss_cons_dot_parantheses()
  Function : Returns a dot-parantheses format of msa->ss_cons if it exists, else dies via croak.
  Args     : None
  Returns  : msa->ss_cons in dot-parantheses format, if it exists, else dies

=cut

sub get_ss_cons_dot_parantheses { 
  my ( $self ) = @_;

  $self->_check_msa();
  if(! $self->has_ss_cons()) { croak "Trying to fetch SS_cons from MSA but it does not exist"; }
  my $ss_cons = _c_get_ss_cons( $self->{esl_msa} );
  # convert all basepairs to '(' and ')'
  $ss_cons =~ tr/\<\>\[\]\{\}/\(\)\(\)\(\)/; 
  # convert all single stranded positions (everything but '(' and ')') to '.'
  $ss_cons =~ s/[^\(\)]/\./g;
 
  return $ss_cons;
}

#-------------------------------------------------------------------------------

=head2 get_ss_cons_ct

  Title    : get_ss_cons_ct
  Incept   : EPN, Mon Jul  7 09:41:58 2014
  Usage    : $msaObject->get_ss_cons_ct()
  Function : Returns a 'CT' array describing the consensus secondary structure
           : of an msa.
  Args     : msa
  Returns  : a 'CT' array, msa->alen+1 elements
           : ct[i] is the position that 'i' basepairs to, else '0' [1..alen] (NOT 0..alen-1)

=cut

sub get_ss_cons_ct {
  my ( $self ) = @_;

   $self->_check_msa();
  if(! $self->has_ss_cons()) { croak "Trying to get a CT array for a SS_cons from MSA but SS_cons does not exist"; }
  my @ctA = _c_get_ss_cons_ct($self->{esl_msa});

  return @ctA;
}

#-------------------------------------------------------------------------------

=head2 set_ss_cons

  Title    : set_ss_cons
  Incept   : EPN, Tue Feb 18 10:15:25 2014
  Usage    : $msaObject->set_ss_cons()
  Function : Sets msa->ss_cons given a string.
  Args     : $ss_cons_str: string that will become msa->ss_cons
  Returns  : void
  Dies     : if length($ss_cons_str) != msa->alen

=cut

sub set_ss_cons { 
  my ( $self, $ss_cons_str ) = @_;

  $self->_check_msa();
  if(length($ss_cons_str) != $self->alen) { croak "Trying to set SS_cons with string of incorrect length"; }
  return _c_set_ss_cons( $self->{esl_msa}, $ss_cons_str, 0 );
}

#-------------------------------------------------------------------------------

=head2 set_ss_cons_wuss

  Title    : set_ss_cons_wuss
  Incept   : EPN, Mon Jul  7 11:12:23 2014
  Usage    : $msaObject->set_ss_cons_wuss()
  Function : Sets msa->ss_cons given a string and convert it to full WUSS annotation.
  Args     : $ss_cons_str: string that will become msa->ss_cons
  Returns  : void
  Dies     : if length($ss_cons_str) != msa->alen, or there is a problem converting to full WUSS

=cut

sub set_ss_cons_wuss { 
  my ( $self, $ss_cons_str ) = @_;

  $self->_check_msa();
  if(length($ss_cons_str) != $self->alen) { croak "Trying to set SS_cons with string of incorrect length"; }
  return _c_set_ss_cons( $self->{esl_msa}, $ss_cons_str, 1 );
}

#-------------------------------------------------------------------------------

=head2 set_blank_ss_cons

  Title    : set_blank_ss_cons
  Incept   : EPN, Tue Oct 22 10:38:39 2013
  Usage    : $msaObject->set_blank_ss_cons()
  Function : Sets msa->ss_cons as all '.' characters (zero basepairs).
  Args     : None
  Returns  : Nothing

=cut

sub set_blank_ss_cons { 
  my ( $self ) = @_;

  $self->_check_msa();
  return _c_set_blank_ss_cons( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 get_sqname

  Title    : get_sqname
  Incept   : EPN, Mon Jan 28 09:35:21 2013
  Usage    : $msaObject->get_sqname($idx)
  Function : Returns name of sequence $idx in MSA.
  Args     : index of sequence 
  Returns  : name of sequence $idx (esl_msa->sqname[$idx])
             ($idx runs 0..nseq-1)

=cut

sub get_sqname {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  return _c_get_sqname( $self->{esl_msa}, $idx );
}

#-------------------------------------------------------------------------------

=head2 get_sqidx

  Title    : get_seqidx
  Incept   : EPN, Mon Feb  3 14:20:07 2014
  Usage    : $msaObject->_get_sqidx($sqname)
  Function : Return the index of sequence $sqname in the MSA.
  Args     : $sqname: the sequence of interest
  Returns  : index of $sqname in $msa, or -1 if it does not exit
  Dies     : if msa->index is not setup
=cut

sub get_sqidx {
  my ( $self, $sqname ) = @_;

  $self->_check_msa();
  $self->_check_index();
  
  return _c_get_sqidx($self->{esl_msa}, $sqname);
}

#-------------------------------------------------------------------------------

=head2 set_sqname

  Title    : set_sqname
  Incept   : EPN, Mon Jan 28 09:48:42 2013
  Usage    : $msaObject->set_sqname($idx, $newName)
  Function : Returns nothing
  Args     : index of sequence, new sequence name. 
  Returns  : void

=cut

sub set_sqname {
  my ( $self, $idx, $newname ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  _c_set_sqname( $self->{esl_msa}, $idx, $newname );
  return;
}

#-------------------------------------------------------------------------------

=head2 has_sqwgts

  Title    : has_sqwgts
  Incept   : EPN, Tue Apr  1 13:50:53 2014
  Usage    : $msaObject->has_sqwgts()
  Function : Returns '1' if MSA has valid sequence weights, else returns '0'
  Args     : none
  Returns  : '1' if MSA has valid sequence weights, else '0'

=cut

sub has_sqwgts {
  my ( $self ) = @_;

  $self->_check_msa();
  return _c_has_sqwgts( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 get_sqwgt

  Title    : get_sqwgt
  Incept   : EPN, Fri May 24 10:47:03 2013
  Usage    : $msaObject->get_sqwgt($idx)
  Function : Returns weight of sequence $idx in MSA.
  Args     : index of sequence 
  Returns  : weight of sequence $idx (esl_msa->wgt[$idx])
             ($idx runs 0..nseq-1)
  Dies     : if MSA does not have sequence weight annotation
=cut

sub get_sqwgt {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  if(! $self->has_sqwgts) { croak "trying to get sequence weight, but none exist."; }
  return _c_get_sqwgt( $self->{esl_msa}, $idx );
}

#-------------------------------------------------------------------------------

=head2 remove_sqwgts

  Title    : remove_sqwgts
  Incept   : EPN, Thu Feb 20 14:25:35 2014
  Usage    : $msaObject->remove_sqwgts()
  Function : Removes GF WT annotation from an MSA.
  Args     : none
  Returns  : void

=cut

sub remove_sqwgts {
  my ( $self ) = @_;

  $self->_check_msa();
  _c_remove_sqwgts( $self->{esl_msa} );
  return;
}

#-------------------------------------------------------------------------------

=head2 get_accession

  Title    : get_accession
  Incept   : EPN, Fri Feb  1 11:43:08 2013
  Usage    : $msaObject->get_accession()
  Function : Gets accession for MSA.
  Args     : none
  Returns  : the accession, a string

=cut

sub get_accession {
  my ($self) = @_;

  $self->_check_msa();
  return _c_get_accession( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 get_name

  Title    : get_name
  Incept   : EPN, Mon Jul  8 10:00:44 2013
  Usage    : $msaObject->get_name($name)
  Function : Gets name for MSA.
  Args     : none
  Returns  : the name, a string

=cut

sub get_name {
  my ($self) = @_;

  $self->_check_msa();
  return _c_get_name( $self->{esl_msa} );
}

#-------------------------------------------------------------------------------

=head2 set_accession

  Title    : set_accession
  Incept   : EPN, Fri Feb  1 11:11:05 2013
  Usage    : $msaObject->set_accession($acc)
  Function : Sets accession for MSA in <esl_msa>
  Args     : accession string to set
  Returns  : void

=cut

sub set_accession {
  my ( $self, $newname ) = @_;

  $self->_check_msa();
  my $status = _c_set_accession( $self->{esl_msa}, $newname );
  if ( $status != $ESLOK ) {
    croak "unable to set name (failure in C code)";
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 set_name

  Title    : set_name
  Incept   : EPN, Fri Feb  1 11:11:05 2013
  Usage    : $msaObject->set_name($acc)
  Function : Sets name for MSA in <esl_msa>
  Args     : name string to set
  Returns  : void

=cut

sub set_name {
  my ( $self, $newname ) = @_;

  $self->_check_msa();
  my $status = _c_set_name( $self->{esl_msa}, $newname );
  if ( $status != $ESLOK ) {
    croak "unable to set name (failure in C code)";
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 write_msa

  Title    : write_msa
  Incept   : EPN, Mon Jan 28 09:58:19 2013
  Usage    : $msaObject->write_msa($fileLocation)
  Function : Write MSA to a file
  Args     : $outfile: name of output file, if "STDOUT" output to stdout, not to a file
           : $format:  ('stockholm', 'pfam', 'a2m', 'phylip', 'phylips', 'psiblast', 'selex', 'afa', 'clustal', 'clustallike', 'fasta')
           :           if 'fasta', write out seqs in unaligned fasta.
           : $do_append_if_exists: if $outfile exists, append to it, else create it
  Returns  : void

=cut

sub write_msa {
  my ( $self, $outfile, $format, $do_append_if_exists ) = @_;

  my $status;

  if(! defined $do_append_if_exists) { $do_append_if_exists = 0; }

  $self->_check_msa();
  if ( !defined $format ) {
    $format = "stockholm";
  }
  if ($format eq "fasta") { # special case, write as unaligned fasta
    $status = _c_write_msa_unaligned_fasta( $self->{esl_msa}, $outfile, $do_append_if_exists );
  }
  elsif (    $format eq "stockholm"
          || $format eq "pfam"
          || $format eq "a2m"
          || $format eq "phylip"
          || $format eq "phylips"
          || $format eq "psiblast"
          || $format eq "selex"
          || $format eq "afa" 
          || $format eq "clustal"
          || $format eq "clustallike")
  {
    $status = _c_write_msa( $self->{esl_msa}, $outfile, $format, $do_append_if_exists );
  }
  else { 
    croak "format must be \"stockholm\" or \"pfam\" or \"afa\" or \"clustal\" or \"fasta\"";
  }
  if ( $status != $ESLOK ) {
    if ( $status == $ESLEINVAL ) {
      croak "problem writing out msa, invalid format $format";
    }
    elsif ( $status == $ESLFAIL ) {
      croak "problem writing out msa, unable to open $outfile for writing or appending"; 
    }
    elsif ( $status == $ESLEMEM ) {
      croak "problem writing out msa, out of memory";
    }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 write_single_unaligned_seq

  Title    : write_single_unaligned_seq
  Incept   : EPN, Mon Nov  4 09:53:50 2013
  Usage    : Bio::Easel::MSA->write_single_unaligned_seq($idx)
  Function : Writes out a single seq from MSA in FASTA format to a file.
  Args     : $idx:     index of seq in MSA to output
           : $outfile: name of file to create
           : $do_append_if_exists: if $outfile exists, append to it, else create it
  Returns  : void

=cut

sub write_single_unaligned_seq { 
  my ($self, $idx, $outfile, $do_append_if_exists) = @_;

  my $status;

  if(! defined $do_append_if_exists) { $do_append_if_exists = 0; }

  $self->_check_msa();
  $status = _c_write_single_unaligned_seq( $self->{esl_msa}, $idx, $outfile, $do_append_if_exists);
  if($status != $ESLOK) { 
    if   ($status == $ESLEINVAL) { 
      croak "problem writing out single seq idx $idx, idx out of bounds";
    }
    elsif($status == $ESLFAIL) { 
      croak "problem writing out single seq idx $idx, unable to open $outfile for writing or appending"; 
    }
    elsif ( $status == $ESLEMEM ) {
      croak "problem writing out msa, out of memory";
    }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 any_allgap_columns

  Title    : any_allgap_columns
  Incept   : EPN, Mon Jan 28 10:44:12 2013
  Usage    : $msaObject->any_allgap_columns()
  Function : Return TRUE if any all gap columns exist in MSA
  Args     : none
  Returns  : TRUE if any all gap columns, FALSE if not

=cut

sub any_allgap_columns {
  my ($self) = @_;

  $self->_check_msa();
  return _c_any_allgap_columns( $self->{esl_msa}, "-_.~" ); # gap string of "-_.~" only relevant if MSA is not digitized 
}

#-------------------------------------------------------------------------------

=head2 average_id

  Title    : average_id
  Incept   : EPN, Fri Feb  1 06:59:50 2013
  Usage    : $msaObject->average_id($max_nseq)
  Function : Calculate and return average fractional identity of 
           : all pairs of sequences in msa. If more than $max_nseq
           : sequences exist in the seed, an average is computed
           : over a stochastic sample (the sample and thus the 
           : result with vary over multiple runs).
  Args     : max number of sequences for brute force calculation
  Returns  : average percent id of all seq pairs or a sample
  
=cut

sub average_id {
  my ( $self, $max_nseq ) = @_;

  $self->_check_msa();
  if ( !defined $max_nseq ) {
    $max_nseq = 100;
  }

  # average percent id is expensive to calculate, so we set it once calc'ed
  if ( !defined $self->{average_id} ) {
    $self->{average_id} = _c_average_id( $self->{esl_msa}, $max_nseq );
  }
  return $self->{average_id};
}

#-------------------------------------------------------------------------------

=head2 get_sqstring_aligned

  Title    : get_sqstring_aligned
  Incept   : EPN, Fri May 24 11:02:21 2013
  Usage    : $msaObject->get_sqstring_aligned()
  Function : Return an aligned sequence from an MSA.
  Args     : index of sequence you want
  Returns  : aligned sequence index idx

=cut

sub get_sqstring_aligned {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  return _c_get_sqstring_aligned( $self->{esl_msa}, $idx );
}

#-------------------------------------------------------------------------------

=head2 swap_gap_and_closest_residue

  Title    : swap_gap_and_closest_residue
  Incept   : EPN, Fri Feb 19 06:39:54 2021
  Usage    : $msaObject->swap_gap_and_closest_residue()
  Function : For a specific sequence, swap a gap in the alignment
             with the nearest residue before or after it.
             Also relocates ss,sa annotation for the relocated residue, if it exists
             Changes pp annotation for the relocated residue to 0, if it exists
             
  Args     : seqidx:    sequence index we are swapping residue in
             gap_apos:  aligned position of the gap [1..alen]
             do_before: '1' to swap with first residue before gap,
                        '0' to swap with first residue after gap
  Returns  : Two values: $ret_apos (or -1) and error message (or "")
             If successful: 
                return value 1: $res_apos: (integer) the position $gap_apos was switched with
                return value 2: "", empty string indicating no error
             If unsuccessful because either $gap_apos is not a gap for $seqidx, 
             or   $do_before and no nongaps exist before $gap_apos
             or ! $do_before and no nongaps exist after $gap_apos
                return value 1: -1, did not swap, so returns -1 as $res_apos
                return value 2: string beginning with "ERROR" explaining problem
  Dies     : If there's a problem getting or setting sqstring or annotation strings
=cut

sub swap_gap_and_closest_residue { 
  my ( $self, $seqidx, $gap_apos, $do_before ) = @_;

  my $sub_name = "swap_gap_and_closest_residue()";
  $self->_check_msa();
  $self->_check_sqidx($seqidx);

  # contract checks
  my $alen = $self->alen;
  if(($gap_apos < 0) || ($gap_apos > $alen)) { 
    return (-1, "ERROR: invalid gap alignment position gap_apos > alen ($gap_apos > $alen)");
  }

  my $sqstring = _c_get_sqstring_aligned($self->{esl_msa}, $seqidx);
  my @sqstring_A = split("", $sqstring);

  # get annotation strings, if any
  my $ppstring = undef;
  my @ppstring_A = ();
  my $sastring = undef;
  my @sastring_A = ();
  my $ssstring = undef;
  my @ssstring_A = ();
  if(_c_check_ppidx($self->{esl_msa}, $seqidx)) { 
    $ppstring = _c_get_ppstring_aligned($self->{esl_msa}, $seqidx);
    @ppstring_A = split("", $ppstring);
  }    
  if(_c_check_saidx($self->{esl_msa}, $seqidx)) { 
    $sastring = _c_get_sastring_aligned($self->{esl_msa}, $seqidx);
    @sastring_A = split("", $sastring);
  }    
  if(_c_check_ssidx($self->{esl_msa}, $seqidx)) { 
    $ssstring = _c_get_ssstring_aligned($self->{esl_msa}, $seqidx);
    @ssstring_A = split("", $ssstring);
  }    

  if($sqstring_A[($gap_apos-1)] !~ m/[\-\.\~]/) { 
    return (-1, sprintf("ERROR in $sub_name: aligned position $gap_apos for sequence $seqidx is not a gap but %s", $sqstring_A[($gap_apos-1)]));
  }
  my $res_apos; # aligned position of residue to swap with gap at $gap_apos
  my $apos;
  if($do_before) { 
    for($apos = ($gap_apos-1); $apos >= 1; $apos--) { 
      if($sqstring_A[($apos-1)] !~ m/[\-\.\~]/) { 
        $res_apos = $apos;
        $apos = 0; # breaks loop
      }
    }
    if(! defined $res_apos) { 
      return (-1, "ERROR in $sub_name: no residues, no nongaps exist before gap at alignment position $gap_apos");
    }
  }
  else { # ! $do_before, so do_after
    for($apos = ($gap_apos+1); $apos <= $alen; $apos++) { 
      if($sqstring_A[($apos-1)] !~ m/[\-\.\~]/) { 
        $res_apos = $apos;
        $apos = $alen+1; # breaks loop
      }
    }
    if(! defined $res_apos) { 
      return (-1, "ERROR in $sub_name: no residues, no nongaps exist after gap at alignment position $gap_apos");
    }
  }

  # do the swap and set the strings in the MSA
  my $save_char;
  $save_char = $sqstring_A[($gap_apos-1)];
  $sqstring_A[($gap_apos-1)] = $sqstring_A[($res_apos-1)];
  $sqstring_A[($res_apos-1)] = $save_char;
  $sqstring = join("", @sqstring_A);
  _c_set_sqstring_aligned($self->{esl_msa}, $sqstring, $seqidx);

  if(defined $ppstring) { 
    $save_char = $ppstring_A[($gap_apos-1)];
    # $ppstring_A[($gap_apos-1)] = $ppstring_A[($res_apos-1)];
    $ppstring_A[($gap_apos-1)] = "0"; # set new PP to 0 
    $ppstring_A[($res_apos-1)] = $save_char;
    $ppstring = join("", @ppstring_A);
    _c_set_existing_ppstring_aligned($self->{esl_msa}, $ppstring, $seqidx);
  }
  if(defined $sastring) { 
    $save_char = $sastring_A[($gap_apos-1)];
    $sastring_A[($gap_apos-1)] = $sastring_A[($res_apos-1)];
    $sastring_A[($res_apos-1)] = $save_char;
    $sastring = join("", @sastring_A);
    _c_set_existing_sastring_aligned($self->{esl_msa}, $sastring, $seqidx);
  }
  if(defined $ssstring) { 
    $save_char = $ssstring_A[($gap_apos-1)];
    $ssstring_A[($gap_apos-1)] = $ssstring_A[($res_apos-1)];
    $ssstring_A[($res_apos-1)] = $save_char;
    $ssstring = join("", @ssstring_A);
    _c_set_existing_ssstring_aligned($self->{esl_msa}, $ssstring, $seqidx);
  }

  return ($res_apos, "");
}

#-------------------------------------------------------------------------------

=head2 get_sqstring_aligned_and_truncated

  Title    : get_sqstring_aligned_and_truncated
  Incept   : EPN, Fri Mar 15 14:58:04 2019
  Usage    : $msaObject->get_sqstring_aligned_and_truncated()
  Function : Return an aligned sequence from an MSA
           : truncated to include only aligned positions 
           : from $start to $stop.
  Args     : $idx:    index of sequence you want
           : $astart: start alignment position [1..alen]
           : $astop:  stop alignment position  [1..alen]
  Returns  : aligned sequence index idx from $astart..$astop
  Dies     : if $astart and $astop don't make sense or
           : sequence index $idx does not exist
=cut

sub get_sqstring_aligned_and_truncated {
  my ( $self, $idx, $astart, $astop ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  my $alen = $self->alen;
  if(($astart < 0) || ($astart > $alen)) { 
    croak "ERROR: invalid alignment position astart > alen ($astart > $alen)";
  }
  if(($astop < 0) || ($astop > $alen)) { 
    croak "ERROR: invalid alignment position astop > alen ($astop > $alen)";
  }
  if($astart > $astop) { 
    croak "ERROR: invalid alignment range astart > astop ($astart..$astop)";
  }
  my $sqstring = _c_get_sqstring_aligned( $self->{esl_msa}, $idx );

  return substr($sqstring, ($astart-1), ($astop-$astart+1));
}

#-------------------------------------------------------------------------------

=head2 get_ppstring_aligned

  Title    : get_ppstring_aligned
  Incept   : EPN, Mon Jul  7 09:12:09 2014
  Usage    : $msaObject->get_ppstring_aligned()
  Function : Return an aligned posterior probability annotation for a seq from an MSA.
  Args     : index of sequence you want PP annotation
  Returns  : aligned posterior probability annotation for sequence index idx

=cut

sub get_ppstring_aligned {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  $self->_check_ppidx($idx);
  return _c_get_ppstring_aligned( $self->{esl_msa}, $idx );
}


#-------------------------------------------------------------------------------

=head2 get_sastring_aligned

  Title    : get_sastring_aligned
  Incept   : EPN, Fri Feb 19 15:09:04 2021
  Usage    : $msaObject->get_sastring_aligned()
  Function : Return an aligned SA annotation string for a seq from an MSA.
  Args     : index of sequence you want SA annotation
  Returns  : aligned SA annotation for sequence index idx

=cut

sub get_sastring_aligned {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  $self->_check_saidx($idx);
  return _c_get_sastring_aligned( $self->{esl_msa}, $idx );
}

#-------------------------------------------------------------------------------

=head2 get_ssstring_aligned

  Title    : get_ssstring_aligned
  Incept   : EPN, Mon Jul  7 09:12:09 2014
  Usage    : $msaObject->get_ssstring_aligned()
  Function : Return an aligned posterior probability annotation for a seq from an MSA.
  Args     : index of sequence you want SS annotation
  Returns  : aligned SS annotation for sequence index idx

=cut

sub get_ssstring_aligned {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  $self->_check_ssidx($idx);
  return _c_get_ssstring_aligned( $self->{esl_msa}, $idx );
}


#-------------------------------------------------------------------------------

=head2 get_sqstring_unaligned

  Title    : get_sqstring_unaligned
  Incept   : EPN, Fri May 24 11:02:21 2013
  Usage    : $msaObject->get_sqstring_unaligned()
  Function : Return an unaligned sequence from an MSA.
  Args     : index of sequence you want
  Returns  : unaligned sequence, index idx

=cut

sub get_sqstring_unaligned {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  return _c_get_sqstring_unaligned( $self->{esl_msa}, $idx );
}

#-------------------------------------------------------------------------------

=head2 get_sqstring_unaligned_and_truncated

  Title    : get_sqstring_unaligned_and_truncated
  Incept   : EPN, Fri Mar 15 14:59:44 2019
  Usage    : $msaObject->get_sqstring_aligned_and_truncated()
  Function : Return an unaligned sequence from an MSA
           : truncated to include only aligned positions 
           : from $start to $stop.
  Args     : $idx:    index of sequence you want
           : $astart: start alignment position [1..alen]
           : $astop:  stop alignment position  [1..alen]
           : $gapstr: string of characters to consider as gaps,
           :          if undefined we use '.-~'
  Returns  : unaligned sequence index idx from $astart..$astop
  Dies     : if $astart and $astop don't make sense or
           : sequence index $idx does not exist

=cut

sub get_sqstring_unaligned_and_truncated {
  my ( $self, $idx, $astart, $astop, $gapstr ) = @_;
  
  if(! defined $gapstr) { $gapstr = ".-~"; }
  my $sqstring = $self->get_sqstring_aligned_and_truncated($idx, $astart, $astop);

  $sqstring =~ s/[\Q$gapstr\E]//g;

  return $sqstring;
}


#-------------------------------------------------------------------------------

=head2 get_sqlen

  Title    : get_sqlen
  Incept   : EPN, Fri Feb  1 16:56:24 2013
  Usage    : $msaObject->get_sqlen()
  Function : Return unaligned sequence length of 
           : sequence <idx>.
  Args     : index of sequence you want length of
  Returns  : unaligned sequence length of sequence idx

=cut

sub get_sqlen {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  return _c_get_sqlen( $self->{esl_msa}, $idx );
}

#-------------------------------------------------------------------------------

=head2 get_column

  Title    : get_column
  Incept   : EPN, Tue Feb 18 09:22:05 2014
  Usage    : $msaObject->get_column($apos)
  Function : Return a string that is column $apos of the alignment,
           : where apos runs 1..alen. So to get the first column
           : of the alignment pass in 1 for $apos, pass in 2 for the
           : second column, etc.
  Args     : $apos: [1..alen] the desired column of the alignment 
  Returns  : $column: column $apos of the alignment, as a string

=cut

sub get_column {
  my ( $self, $apos ) = @_;

  $self->_check_msa();
  $self->_check_ax_apos($apos);

  return _c_get_column( $self->{esl_msa}, $apos );
}
#-------------------------------------------------------------------------------

=head2 count_residues

  Title    : count_residues
  Incept   : March 5, 2013
  Usage    : $msaObject->count_residues()
  Function : Calculate and return total sequence length
           : in the MSA.
  Args     : none
  Returns  : total sequence length

=cut

sub count_residues
{
  my ($self) = @_;

  $self->_check_msa();
  if(!defined $self->{nresidue})
  {
    $self->{nresidue} = _c_count_residues($self->{esl_msa});
  }
  return $self->{nresidue};
}

#-------------------------------------------------------------------------------

=head2 average_sqlen

  Title    : average_sqlen
  Incept   : EPN, Fri Feb  1 06:59:50 2013
  Usage    : $msaObject->average_sqlen()
  Function : Calculate and return average unaligned sequence length
           : in the MSA.
  Args     : none
  Returns  : average unaligned sequence length

=cut

sub average_sqlen {
  my ($self) = @_;

  $self->_check_msa();

  # this could be expensive to calculate if nseq is very high, so we store it
  if ( !defined $self->{average_sqlen} ) {
    $self->{average_sqlen} = _c_average_sqlen( $self->{esl_msa} );
  }
  return $self->{average_sqlen};
}

#-------------------------------------------------------------------------------

=head2 rfam_qc_stats

  Title    : rfam_qc_stats
  Incept   : EPN, Fri Feb  1 10:29:11 2013
  Usage    : $msaObject->rfam_qc_stats($fam_outfile, $seq_outfile, $bp_outfile)
  Function : Calculate per-family, per-sequence and per-basepair stats for a
           : SS_cons annotated RNA alignment and output it. 
           : See 'Purpose' section of _c_rfam_qc_stats() C function in
           : MSA.c for more information.
  Args     : fam_outfile: name of output file for per-family stats
           : seq_outfile: name of output file for per-sequence stats
           : bp_outfile:  name of output file for per-basepair stats
  Returns  : void

=cut

sub rfam_qc_stats {
  my ( $self, $fam_outfile, $seq_outfile, $bp_outfile ) = @_;

  $self->_check_msa();
  my $status = _c_rfam_qc_stats( $self->{esl_msa}, $fam_outfile, $seq_outfile, $bp_outfile);
  if ( $status != $ESLOK ) {
    croak "ERROR: unable to calculate rfam qc stats";
  }

  return;
}

#-------------------------------------------------------------------------------

=head2 setDesc

  Title    : setDesc
  Incept   : EPN, Tue Mar 21 13:35:18 2017
  Usage    : $msaObject->setDesc($value)
  Function : Set the description line of an ESL_MSA object.
  Args     : $value: text for the line
  Returns  : void

=cut

sub setDesc {
  my ( $self, $value ) = @_;

  $self->_check_msa();
  my $status = _c_setDesc( $self->{esl_msa}, $value );
  if ( $status != $ESLOK ) { croak "ERROR: unable to set Desc annotation"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 setAccession

  Title    : setAccession
  Incept   : EPN, Tue Mar 21 13:36:34 2017
  Usage    : $msaObject->setAccession($value)
  Function : Set the accession field of an ESL_MSA object.
  Args     : $value: text for the line
  Returns  : void

=cut

sub setAccession {
  my ( $self, $value ) = @_;

  $self->_check_msa();
  my $status = _c_setAccession( $self->{esl_msa}, $value );
  if ( $status != $ESLOK ) { croak "ERROR: unable to set Accession"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 getDesc

  Title    : getDesc
  Incept   : EPN, Tue Mar 21 10:18:25 2017
  Usage    : $msaObject->getDesc()
  Function : Return description line of an ESL_MSA
           : as a string, or "" if it does not exist
  Args     : none
  Returns  : $descstr: desc annotation, as a string.

=cut

sub getDesc {
  my ( $self ) = @_;

  $self->_check_msa();
  if(! (_c_hasDesc( $self->{esl_msa} ))) { 
    return "";
  }
  else { 
    return _c_getDesc( $self->{esl_msa} );
  }
}

#-------------------------------------------------------------------------------

=head2 getAccession

  Title    : getAccession
  Incept   : EPN, Tue Mar 21 10:20:41 2017
  Usage    : $msaObject->getAccession()
  Function : Return accession field of an ESL_MSA
           : as a string, or "" if it does not exist
  Args     : none
  Returns  : $accstr: accession, as a string.

=cut

sub getAccession {
  my ( $self ) = @_;

  $self->_check_msa();
  if(! (_c_hasAccession( $self->{esl_msa} ))) { 
    return "";
  }
  else { 
    return _c_getAccession( $self->{esl_msa} );
  }
}

#-------------------------------------------------------------------------------

=head2 addGF

  Title    : addGF
  Incept   : EPN, Fri Feb  1 17:43:38 2013
  Usage    : $msaObject->addGF($tag, $value)
  Function : Add GF tag/value to a C ESL_MSA object.
  Args     : $tag:   two letter tag 
           : $value: text for the line
  Returns  : void

=cut

sub addGF {
  my ( $self, $tag, $value ) = @_;

  $self->_check_msa();
  my $status = _c_addGF( $self->{esl_msa}, $tag, $value );
  if ( $status != $ESLOK ) { croak "ERROR: unable to add GF annotation"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGS

  Title    : addGS
  Incept   : EPN, Fri Feb  1 17:43:38 2013
  Usage    : $msaObject->addGF($tag, $value)
  Function : Add GS tag/value for a specific sequence 
           : to a C ESL_MSA object.
  Args     : $tag:   two letter tag 
           : $value: text for the line
           : $sqidx: seq index to add GS for
  Returns  : void
  Dies     : via croak() if seq $sqidx doesn't exist
=cut

sub addGS {
  my ( $self, $tag, $value, $sqidx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);

  my $status = _c_addGS( $self->{esl_msa}, $sqidx, $tag, $value );
  if ( $status != $ESLOK ) { croak "ERROR: unable to add GS annotation"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGC

  Title    : addGC
  Incept   : EPN, Wed Feb  4 10:54:27 2015
  Usage    : $msaObject->addGC($tag, $annAR)
  Function : Add GC annotation to an ESL_MSA with
           : tag <$tag> and column annotation in 
           : the array referenced by <$annAR>
  Args     : $tag: name of GC annotation (e.g. SS_cons)
           : $annAR: ref to array of per-column annotation
           :         must be same size as alignment length.
  Returns  : void

=cut

sub addGC {
  my ( $self, $tag, $annAR ) = @_;

  # contract checks
  if((! defined $annAR) || (scalar(@{$annAR}) != $self->alen)) { croak "ERROR: unable to add GC annotation because it is empty or the wrong length"; }
  $self->_check_msa();

  # create the annotation string
  my $annstr = "";
  foreach my $el (@{$annAR}) { $annstr .= $el; }

  # add it
  my $status = _c_addGC( $self->{esl_msa}, $tag, $annstr);
  if ( $status != $ESLOK ) { croak "ERROR: unable to add GC annotation"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGC_identity

  Title    : addGC_identity
  Incept   : EPN, Fri Nov  8 09:31:00 2013
  Usage    : $msaObject->addGC_identity($use_res)
  Function : Add GC annotation to an ESL_MSA with
           : tag 'ID' with a '*' indicating columns
           : for which all sequences have an identical
           : residue, or instead of '*' use the
           : residue itself, if $use_res is 1.
  Args     : $use_res: '1' to use residue for marking 100% 
           :          identical columns, '0' to use '*'.
  Returns  : void

=cut

sub addGC_identity {
  my ( $self, $use_res ) = @_;

  $self->_check_msa();
  my $status = _c_addGC_identity( $self->{esl_msa}, $use_res );
  if ( $status != $ESLOK ) { croak "ERROR: unable to add GC ID annotation"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGC_rf_column_numbers

  Title    : addGC_rf_column_numbers
  Incept   : EPN, Fri Jun 11 13:26:23 2021
  Usage    : $msaObject->addGC_rf_column_numbers()
  Function : Add GC annotation to an ESL_MSA with
           : tag 'RFCOLX...' for RF positions.
  Args     : void
  Returns  : void
  Dies     : via croak() if msa does not have RF annotation
=cut

sub addGC_rf_column_numbers {
  my ( $self ) = @_;

  $self->_check_msa();
  if(! $self->has_rf) { croak "Trying to number RF gap columns, but no RF annotation exists in the MSA"; }
  my @num_str_A = ();
  _get_nongap_numbering_for_aligned_string($self->get_rf, \@num_str_A, ".-~", ".");

  my $ndig = scalar(@num_str_A);

  for(my $d = $ndig-1; $d >= 0; $d--) { 
    my $tag = "RFCOL";
    for(my $before = 0; $before < (($ndig-1)-$d); $before++) { 
      $tag .= ".";
    }
    $tag .= "X";
    for(my $after = 0; $after < $d; $after++) { 
      $tag .= ".";
    }
    my $status = _c_addGC( $self->{esl_msa}, $tag, $num_str_A[$d] );
    if ( $status != $ESLOK ) { croak "ERROR: unable to add GC RFCOL annotation"; }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGC_all_column_numbers

  Title    : addGC_all_column_numbers
  Incept   : EPN, Fri Jun 11 13:26:23 2021
  Usage    : $msaObject->addGC_all_column_numbers()
  Function : Add GC annotation to an ESL_MSA with
           : tag 'COLX...' for all positions.
  Args     : void
  Returns  : void
  Dies     : via croak() if msa has 0 seqs (should be impossible)
=cut

sub addGC_all_column_numbers {
  my ( $self ) = @_;

  $self->_check_msa();
  my @num_str_A = ();
  if($self->nseq < 1) { croak "Trying to number columns, but no seqs exists in the MSA"; }
  # fetch 1st seq, we can use any, and set gap_str to "", this tells _get_nongap_numbering_for_aligned_string()
  # to number all columns
  _get_nongap_numbering_for_aligned_string($self->get_sqstring_aligned(1), \@num_str_A, "", ".");  

  my $ndig = scalar(@num_str_A);

  for(my $d = $ndig-1; $d >= 0; $d--) { 
    my $tag = "COL";
    for(my $before = 0; $before < (($ndig-1)-$d); $before++) { 
      $tag .= ".";
    }
    $tag .= "X";
    for(my $after = 0; $after < $d; $after++) { 
      $tag .= ".";
    }
    my $status = _c_addGC( $self->{esl_msa}, $tag, $num_str_A[$d] );
    if ( $status != $ESLOK ) { croak "ERROR: unable to add GC COL annotation"; }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 getGC_given_tag

  Title    : getGC_given_tag
  Incept   : EPN, Wed Feb  4 14:51:03 2015
  Usage    : $msaObject->getGC_given_tag($tag)
  Function : Return GC annotation named <tag> of an ESL_MSA
           : as a string.
  Args     : $tag:    name of GC annotation
  Returns  : $annstr: GC annotation, as a string.

=cut

sub getGC_given_tag {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  if(! (_c_hasGC( $self->{esl_msa}, $tag ))) { croak("trying to get GC annotation $tag that does not exist"); }
  return _c_getGC_given_tag( $self->{esl_msa}, $tag );
}


#-------------------------------------------------------------------------------

=head2 getGC_given_idx

  Title    : getGC_given_idx
  Incept   : EPN, Wed Feb  4 20:56:31 2015
  Usage    : $msaObject->getGC_given_idx($tagidx)
  Function : Return GC annotation of idx <tagidx> of an ESL_MSA
           : as a string.
  Args     : $tagidx: idx of GC annotation
  Returns  : $annstr: GC annotation, as a string.

=cut

sub getGC_given_idx {
  my ( $self, $tagidx ) = @_;

  $self->_check_msa();
  if($tagidx >= $self->getGC_number) { croak("trying to get GC annotation for tag idx $tagidx that does not exist"); }
  return _c_getGC_given_idx( $self->{esl_msa}, $tagidx );
}

#-------------------------------------------------------------------------------

=head2 hasGC

  Title    : hasGC
  Incept   : EPN, Wed Feb  4 15:28:23 2015
  Usage    : $msaObject->hasGC($tag)
  Function : Return '1' if GC annotation named <tag> exists,
           : else return '0'.
  Args     : $tag:    name of GC annotation (e.g. SS_cons)
  Returns  : '1' if it exists, else '0'

=cut

sub hasGC {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  return (_c_hasGC( $self->{esl_msa}, $tag ));
}

#-------------------------------------------------------------------------------

=head2 getGC_number

  Title    : getGC_number
  Incept   : EPN, Wed Feb  4 17:37:44 2015
  Usage    : $msaObject->getGC_number()
  Function : Return number of GC annotations available.
  Args     : none
  Returns  : number of GC annotations stored in MSA
             (not including SS_cons, SA_cons, PP_cons, RF
              and MM, which are stored in a special way
              (not in msa->gc))

=cut

sub getGC_number {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  return (_c_getGC_number( $self->{esl_msa}));
}


#-------------------------------------------------------------------------------

=head2 getGC_tag

  Title    : getGC_tag
  Incept   : EPN, Wed Feb  4 14:51:03 2015
  Usage    : $msaObject->getGC_tag($tagidx)
  Function : Return GC tag of idx <tagidx> as a string
  Args     : $tagidx: idx of tag you want
  Returns  : $tag: string

=cut

sub getGC_tag {
  my ( $self, $tagidx ) = @_;

  $self->_check_msa();
  if($tagidx >= $self->getGC_number) { croak("trying to get GC tag idx $tagidx that does not exist"); }
  return _c_getGC_tag( $self->{esl_msa}, $tagidx );
}


#-------------------------------------------------------------------------------

=head2 getGC_tagidx

  Title    : getGC_tagidx
  Incept   : EPN, Wed Feb  4 21:03:49 2015
  Usage    : $msaObject->getGC_tagidx($tag)
  Function : Return the idx of GC annotation with tag <tag>.
  Args     : $tag: tag of annotation you want idx of
  Returns  : $tagidx: idx of GC annotation
  Dies     : if annotation with tag $tag does not exist.
=cut

sub getGC_tagidx {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  if(! $self->hasGC($tag)) { croak("trying to get idx of tag $tag that does not exist"); }
  return _c_getGC_tagidx( $self->{esl_msa}, $tag );
}

#-------------------------------------------------------------------------------

=head2 addGR

  Title    : addGR
  Incept   : EPN, Wed Jan 29 11:13:04 2020
  Usage    : $msaObject->addGR($tag, $seqidx, $annAR)
  Function : Add GR annotation to an ESL_MSA for sequence
           : <$sqidx> with tag <$tag> and column annotation
           : in the array referenced by <$annAR>
  Args     : $tag:    name of GC annotation (e.g. SS_cons)
           : $sqidx:  seq index to add GR for [0..nseq-1]
           : $annstr: string that is the per-residue annotation
           :          must be same length as alignment length.
  Returns  : void

=cut

sub addGR {
  my ( $self, $tag, $sqidx, $annstr ) = @_;

  # contract checks
  if((! defined $annstr) || (length($annstr) != $self->alen)) { croak "ERROR: unable to add GR annotation because it is empty or the wrong length"; }
  $self->_check_msa();
  $self->_check_sqidx($sqidx);

  # add it
  my $status = _c_addGR( $self->{esl_msa}, $tag, $sqidx, $annstr);
  if ( $status != $ESLOK ) { croak "ERROR: unable to add GR annotation"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGR_seq_position_numbers

  Title    : addGR_seq_position_numbers
  Incept   : EPN, Fri Jun 11 15:02:07 2021
  Usage    : $msaObject->addGS_seq_position_numbers($sqidx)
  Function : Add GR annotation to an ESL_MSA with
           : tag 'POSX...' indicating the positions of each
           : aligned residue within the sequence
  Args     : void
  Returns  : void
  Dies     : via croak() if seq $sqidx doesn't exist
=cut

sub addGR_seq_position_numbers {
  my ( $self, $sqidx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);

  my @num_str_A = ();
  _get_nongap_numbering_for_aligned_string($self->get_sqstring_aligned($sqidx), \@num_str_A, ".-~", ".");

  my $ndig = scalar(@num_str_A);

  for(my $d = $ndig-1; $d >= 0; $d--) { 
    my $tag = "POS";
    for(my $before = 0; $before < (($ndig-1)-$d); $before++) { 
      $tag .= ".";
    }
    $tag .= "X";
    for(my $after = 0; $after < $d; $after++) { 
      $tag .= ".";
    }
    my $status = _c_addGR( $self->{esl_msa}, $tag, $sqidx, $num_str_A[$d] );
    if ( $status != $ESLOK ) { croak "ERROR: unable to add GR POS annotation for sequence index $sqidx"; }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 addGR_all_seqs_position_numbers

  Title    : addGR_all_seqs_position_numbers
  Incept   : EPN, Mon Jun 14 07:35:39 2021
  Usage    : $msaObject->addGS_all_seqs_position_numbers()
  Function : Add GR annotation to an ESL_MSA with
           : tag 'POSX...' indicating the positions of each
           : aligned residue within the sequence
           : for all sequences
  Args     : void
  Returns  : void
=cut

sub addGR_all_seqs_position_numbers {
  my ( $self ) = @_;

  $self->_check_msa();
  my $nseq = $self->nseq;

  for(my $i = 0; $i < $nseq; $i++) { 
    $self->addGR_seq_position_numbers($i);
  }

  return;
}

#-------------------------------------------------------------------------------

=head2 getGR_given_tag_sqidx

  Title    : getGR_given_tag_sqidx
  Incept   : EPN, Wed Jan 29 11:47:34 2020
  Usage    : $msaObject->getGR_given_tag_sqidx($tag, $sqidx)
  Function : Return GR annotation named <tag> of an ESL_MSA
           : for sequence <$sqidx> as a string.
  Args     : $tag:    name of GR annotation
           : $sqidx:  sequence index [0..nseq-1]
  Returns  : $annstr: GR annotation, as a string.

=cut

sub getGR_given_tag_sqidx {
  my ( $self, $tag, $sqidx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);

  if(! (_c_hasGR_given_tag_sqidx( $self->{esl_msa}, $tag, $sqidx ))) { croak("trying to get GR annotation $tag for seq $sqidx that does not exist"); }
  return _c_getGR_given_tag_sqidx( $self->{esl_msa}, $tag, $sqidx );
}

#-------------------------------------------------------------------------------

=head2 getGR_given_tagidx_sqidx

  Title    : getGR_given_tagidx_sqidx
  Incept   : EPN, Wed Jan 29 12:16:41 2020
  Usage    : $msaObject->getGR_given_tagidx_sqidx($tagidx, $sqidx)
  Function : Return GR annotation of idx <tagidx> of an ESL_MSA
           : for sequence <$sqidx> as a string.
  Args     : $tagidx: idx of GR annotation
           : $sqidx:  sequence index [0..nseq-1]
  Returns  : $annstr: GR annotation, as a string.

=cut

sub getGR_given_tagidx_sqidx {
  my ( $self, $tagidx, $sqidx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);

  if($tagidx >= $self->getGR_number) { croak("trying to get GR annotation for tag idx $tagidx that does not exist"); }
  if(_c_hasGR_given_tagidx_sqidx( $self->{esl_msa}, $tagidx, $sqidx )) { 
    return _c_getGR_given_tagidx_sqidx( $self->{esl_msa}, $tagidx, $sqidx );
  }
  else { 
    croak("trying to get GR annotation for tag idx $tagidx for seq $sqidx, tag exists but not for this seq"); 
  }
}

#-------------------------------------------------------------------------------

=head2 hasGR_given_tag_sqidx

  Title    : hasGR_given_tag_sqidx
  Incept   : EPN, Wed Jan 29 11:29:32 2020
  Usage    : $msaObject->hasGR_given_tag_sqidx($tag, $sqidx)
  Function : Return '1' if GR annotation named <tag> exists
           : for sequence index $sqidx (0..$nseq-1),
           : else return '0'.
  Args     : $tag:   name of unparsed GR annotation
           : $sqidx: seq index we are interested in
  Returns  : '1' if it exists, else '0'

=cut

sub hasGR_given_tag_sqidx {
  my ( $self, $tag, $sqidx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);
  return _c_hasGR_given_tag_sqidx( $self->{esl_msa}, $tag, $sqidx );
}
#-------------------------------------------------------------------------------

=head2 hasGR_given_tagidx_sqidx

  Title    : hasGR_given_tagidx_sqidx
  Incept   : EPN, Wed Jan 29 12:22:16 2020
  Usage    : $msaObject->hasGR_given_tagidx_sqidx($tagidx, $sqidx)
  Function : Return '1' if GR annotation with tag idx <tagidx> exists
           : for sequence index $sqidx (0..$nseq-1),
           : else return '0'.
  Args     : $tagidx: index of tag (not including SS, SA, PP)
           : $sqidx:  seq index we are interested in
  Returns  : '1' if it exists, else '0'

=cut

sub hasGR_given_tagidx_sqidx {
  my ( $self, $tagidx, $sqidx ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);
  return _c_hasGR_given_tagidx_sqidx( $self->{esl_msa}, $tagidx, $sqidx );
}

#-------------------------------------------------------------------------------

=head2 hasGR_any_sqidx_given_tag

  Title    : hasGR_any_sqidx_given_tag
  Incept   : EPN, Wed Jan 29 12:44:00 2020
  Usage    : $msaObject->hasGR_given_tag_any_seqidx($tag)
  Function : Return '1' if GR annotation named <tag> exists
           : for any sequence index
           : else return '0'.
  Args     : $tag:   name of unparsed GR annotation
  Returns  : '1' if it exists, else '0'

=cut

sub hasGR_any_sqidx_given_tag {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  return _c_hasGR_any_sqidx_given_tag( $self->{esl_msa}, $tag);
}

#-------------------------------------------------------------------------------

=head2 hasGR_any_sqidx_given_tagidx

  Title    : hasGR_any_sqidx_given_tagidx
  Incept   : EPN, Wed Jan 29 12:46:50 2020
  Usage    : $msaObject->hasGR_any_sqidx_given_tagidx($tagidx)
  Function : Return '1' if GR annotation with tag idx <tagidx> exists
           : else return '0'.
  Args     : $tagidx: index of tag (not including SS, SA, PP)
  Returns  : '1' if it exists, else '0'

=cut

sub hasGR_any_sqidx_given_tagidx {
  my ( $self, $tagidx, $sqidx ) = @_;

  $self->_check_msa();
  return _c_hasGR_any_sqidx_given_tagidx( $self->{esl_msa}, $tagidx);
}

#-------------------------------------------------------------------------------

=head2 getGR_number

  Title    : getGR_number
  Incept   : EPN, Wed Jan 29 12:19:28 2020
  Usage    : $msaObject->getGR_number()
  Function : Return number of GR annotations available.
  Args     : none
  Returns  : number of GR annotations stored in MSA
             (not including SS, SA, and PP, 
               which are stored in a special way
              (not in msa->gr))

=cut

sub getGR_number {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  return (_c_getGR_number( $self->{esl_msa}));
}


#-------------------------------------------------------------------------------

=head2 getGR_tag

  Title    : getGR_tag
  Incept   : EPN, Wed Jan 29 12:28:39 2020
  Usage    : $msaObject->getGR_tag($tagidx)
  Function : Return GR tag of idx <tagidx> as a string
  Args     : $tagidx: idx of tag you want
  Returns  : $tag: string

=cut

sub getGR_tag {
  my ( $self, $tagidx ) = @_;

  $self->_check_msa();
  if($tagidx >= $self->getGR_number) { croak("trying to get GR tag idx $tagidx that does not exist"); }
  return _c_getGR_tag( $self->{esl_msa}, $tagidx );
}

#-------------------------------------------------------------------------------

=head2 getGR_tagidx

  Title    : getGR_tagidx
  Incept   : EPN, Wed Jan 29 12:29:44 2020
  Usage    : $msaObject->getGR_tagidx($tag)
  Function : Return the idx of GR annotation with tag <tag>.
  Args     : $tag: tag of annotation you want idx of
  Returns  : $tagidx: idx of GR annotation
  Dies     : if annotation with tag $tag does not exist.
=cut

sub getGR_tagidx {
  my ( $self, $tag ) = @_;

  $self->_check_msa();
  if(! $self->hasGR_any_sqidx_given_tag($tag)) { croak("trying to get idx of tag $tag that does not exist"); }
  return _c_getGR_tagidx( $self->{esl_msa}, $tag );
}

#-------------------------------------------------------------------------------


=head2 weight_GSC

  Title    : weight_GSC
  Incept   : EPN, Fri May 24 10:42:44 2013
  Usage    : $msaObject->weight_GSC($tag, $value)
  Function : Compute and annotate MSA with sequence weights using the 
           : GSC algorithm. Dies with croak if something goes wrong.
  Args     : none
  Returns  : void

=cut

sub weight_GSC {
  my ( $self ) = @_;

  $self->_check_msa();
  my $status = _c_weight_GSC( $self->{esl_msa} );
  if ( $status != $ESLOK ) { croak "ERROR: unable to calculate GSC weights"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 free_msa

  Title    : free_msa
  Incept   : EPN, Mon Jan 28 11:06:18 2013
  Usage    : $msaObject->free_msa()
  Function : Frees an MSA->{$esl_msa} object
  Args     : name of output file 
  Returns  : void

=cut

sub free_msa {
  my ($self) = @_;

  # don't call _check_msa, if we don't have it, that's okay
  _c_free_msa( $self->{esl_msa} );
  return;
}

#-------------------------------------------------------------------------------

=head2 revert_to_original

  Title    : revert_to_original
  Incept   : EPN, Sat Feb  2 14:53:27 2013
  Usage    : $msaObject->revert_to_original()
  Function : Frees current $msaObject->{esl_msa} object
             and rereads it from $msaObject->{path}
  Args     : none
  Returns  : void

=cut

sub revert_to_original {
  my ($self) = @_;

  if ( !defined $self->{path} ) {
    croak "trying to revert_to_original but path not set";
  }
  $self->free_msa;
  $self->read_msa;
  return;
}

#-------------------------------------------------------------------------------

=head2 weight_id_filter

  Title     : weight_id_filter
  Incept    : March 1, 2013
  Usage     : $msaObject->weight_id_filter($idf)
  Function  : performs id weight filtering on the msa object
  Args      : Identity floating point from 0 to 1, id ratio above which will be filtered
  Returns   : void

=cut

sub weight_id_filter
{
  my($self, $idf) = @_;
  
  my $msa_in = $self->{esl_msa};
  my $msa_out = _c_msaweight_IDFilter($msa_in, $idf);
  
  $self->{esl_msa} = $msa_out;
  
  _c_free_msa($msa_in);
  
  return;
}

#-------------------------------------------------------------------------------

=head2 filter_msa_subset_target_nseq

  Title     : filter_msa_subset_target_nseq
  Incept    : EPN, Thu Nov 21 13:40:52 2013
  Usage     : $msaObject->filter_msa_subset_target_nseq($idf)
  Function  : Filter a subset of sequences in an MSA such that no
            : two sequences in the filtered subset are more than $idf
            : fractionally identical, where $idf is the maximum value
            : that results in <= $nseq sequences (within 0.01, that is, 
            : $idf + 0.01 gives > $nseq sequences).
            : $idf is found by a binary search.
  Args      : $usemeAR:  [0..$i..$self->nseq]: '1' if we should consider sequence $i, else ignore it.
            :            set to all '1' to consider all sequences in the msa.
            : $nseq:     fractional identity threshold no pair of seqs in $keepmeAR will exceed
            : $keepmeAR: [0..$i..$self->nseq]: '1' if seq $i survives the filtering.
            :            note that $keepmeAR->[$i] can only be '1' if $usemeAR->[$i] is also '1'.
  Returns   : $idf:   the fractional identity used to fill keepmeAR
            : $nkeep: number of '1' in keepmeAR

=cut

sub filter_msa_subset_target_nseq
{
  my($self, $usemeAR, $nseq, $keepmeAR) = @_;
  
  # binary search for max fractional id ($f_cur) that results in $nseq sequences
  # we'll filter the alignment such that no two seqs are more than $f_cur similar to each other
  # (or as close as we can get to $nseq by minimal change of 0.01)
  # initializations
  my $f_min = 0.01;
  my $f_opt = 0.01;
  my $f_prv = 1.0;
  my $f_cur = $f_min;
  my ($i, $n);
  my $diff = abs($f_prv - $f_cur);
  while($diff > 0.00999) { # while abs($f_prv - $f_cur) > 0.00999
    # filter based on percent identity
    $n = $self->filter_msa_subset($usemeAR, $f_cur, $keepmeAR);
          
    $f_prv = $f_cur;
    # adjust $f_cur for next round based on how many seqs we have
    if($n > $nseq) { # too many seqs, lower $f_cur
      $f_cur -= ($diff / 2.); 
    }
    else { # too few seqs, raise $f_cur
      if($f_cur > $f_opt) { $f_opt = $f_cur; }
      $f_cur += ($diff / 2.); 
    }
          
    # round to nearest percentage point (0.01)
    $f_cur = (int(($f_cur * 100) + 0.5)) / 100;
          
    if($f_cur < $f_min) { croak "filter_msa_subset_target_nseq: couldn't reach $nseq sequences, with fractional id > $f_min\n"; }
    $diff = abs($f_prv - $f_cur);
  }    
  # $f_opt is our optimal fractional id, the max fractional id that gives <= $nseq seqs
  # call filter_msa_subset once more, to redefine keepmeA
  $n = $self->filter_msa_subset($usemeAR, $f_opt, $keepmeAR);

  return($f_opt, $n);
}

#-------------------------------------------------------------------------------

=head2 filter_msa_subset

  Title     : filter_msa_subset
  Incept    : EPN, Thu Nov 21 13:30:15 2013
  Usage     : $nkept = $msaObject->filter_msa_subset($usmeAR, $idf, $keepmeAR)
  Function  : Filter a subset of sequences in an MSA such that no
            : two sequences in the filtered subset are more than $idf
            : fractionally identical.
            : Similar to weight_id_filter() except does not create a new
            : MSA of only the filtered set, and this function is flexible
            : to only considering a subset of the passed in alignment.
  Args      : $usemeAR:  [0..$i..$self->nseq]: '1' if we should consider sequence $i, else ignore it.
            : $idf:      fractional identity threshold no pair of seqs in $keepmeAR will exceed
            : $keepmeAR: [0..$i..$self->nseq]: '1' if seq $i survives the filtering.
            :            note that $keepmeAR->[$i] can only be '1' if $usemeAR->[$i] is also '1'.
  Returns   : Number of sequences that are '1' in $keepmeAR upon exit.

=cut

sub filter_msa_subset
{
  my($self, $usemeAR, $idf, $keepmeAR) = @_;
  
  my ($i, $j, $pid);  # counters and a pid (pairwise identity) value
  my $nseq = $self->nseq;
  my $nkeep = 0;

  # copy usemeA to keepmeA
  for($i = 0; $i < $nseq; $i++) { 
    $keepmeAR->[$i] = $usemeAR->[$i]; 
    if($keepmeAR->[$i]) { $nkeep++; }
  }
  
  for($i = 0; $i < $nseq; $i++) { 
    if($keepmeAR->[$i]) { # we haven't removed it yet
      for($j = $i+1; $j < $nseq; $j++) { # for every other seq that ... 
        if($keepmeAR->[$j]) { # ... we haven't removed yet
          $pid = _c_pairwise_identity($self->{esl_msa}, $i, $j); # get fractional identity
          if($pid > $idf) { 
            $keepmeAR->[$j] = 0; # remove it
            $nkeep--;
          }
        }
      }
    }
  }

  return $nkeep;
}

#-------------------------------------------------------------------------------

=head2 alignment_coverage

  Title     : alignment_coverage_id
  Incept    : March 5, 2013
  Usage     : $msaObject->alignment_coverage_id()
  Function  : determine coverage ratios of msa
  Args      : None
  Returns   : Success:
                Array from 0 to msa->alen, contains decimals from 0 to 1
                representing coverage ratio of that msa position
              Failure:
                Nothing

=cut

sub alignment_coverage
{
  my ($self, $idf) = @_;
  
  my $msa_in = $self->{esl_msa};
  
  my @output = _c_percent_coverage($msa_in);
  
  return @output;
}

#-------------------------------------------------------------------------------

=head2 count_msa

  Title     : count_msa
  Incept    : EPN, Fri Jul  5 13:46:51 2013
  Usage     : $msaObject->count_msa()
  Function  : Count residues and basepairs in an MSA
  Args      : None
  Returns   : 

=cut

sub count_msa
{
  my ($self) = @_;

  $self->_check_msa();
  $self->_c_count_msa($self->{esl_msa}, 0, 0);

  return;
}

#-------------------------------------------------------------------------------

=head2 pairwise_identity

  Title     : pairwise_identity
  Incept    : EPN, Wed Aug 21 10:19:07 2013
  Usage     : $msaObject->pairwise_identity($i, $j)
  Function  : Return fractional identity between seqs $i and $j in the MSA
  Args      : None
  Returns   : fraction identity of i and j

=cut

sub pairwise_identity
{
  my ($self, $i, $j) = @_;

  $self->_check_msa();
  return _c_pairwise_identity($self->{esl_msa}, $i, $j);
}

#-------------------------------------------------------------------------------

=head2 check_if_prefix_added_to_sqnames

  Title     : check_if_prefix_added_to_sqnames
  Incept    : EPN, Fri Nov  1 15:15:12 2013
  Usage     : $msaObject->check_if_prefix_added_to_sqnames
  Function  : Return '1' if it appears that prefixes were added
            : to all sqnames in the MSA, by Easel to avoid two
            : sequences having an identical name.
  Args      : None
  Returns   : '1' of '0'

=cut

sub check_if_prefix_added_to_sqnames
{
  my ($self) = @_;

  $self->_check_msa();

  # we'll return TRUE only if the following 2 criteria are satisfied:
  # 1) all seqs begin with numerical prefix: \d+\|, e.g. "0001|"
  # 2) at least one duplicated seq name exists AFTER removing numerical prefixes
  my @nameA = ();       # we'll keep track of all names we've seen thus far, to check for dups with
  my $prefix_added = 1; # we'll set to FALSE once we find a counterexample
  my $found_dup    = 0; # we'll set to TRUE once we find a dup
  for(my $i = 0; $i < $self->nseq; $i++) { 
    my $sqname = $self->get_sqname($i);
    if($sqname !~ m/^\d+\|/) { 
      $prefix_added = 0;
      last;
    }
    $sqname =~ s/^\d+\|//;
    if(! $found_dup) { # check if we have a duplicate of this name
      foreach my $sqname2 (@nameA) { 
        if($sqname eq $sqname2) { 
          $found_dup = 1;
          last;
        }
      }
      push(@nameA, $sqname);
    }
  }

  my $ret_val = ($prefix_added && $found_dup) ? 1 : 0;
  return $ret_val;
}

#-------------------------------------------------------------------------------

=head2 remove_prefix_from_sqname

  Title     : remove_prefix_from_sqname
  Incept    : EPN, Fri Nov  1 15:25:27 2013
  Usage     : $msaObject->remove_prefix_from_sqname
  Function  : Remove a numerical prefix from a sequence name.
            : Only meant to be used for MSAs for which 
            : check_if_prefix_added_to_sqnames returned
            : TRUE (which had numerical prefixes added to
            : sqnames to avoid duplicate names).
  Args      : $sqname
  Returns   : $sqname with numerical prefix removed.
  Dies      : If $sqname does not have a numerical prefix,
            : this means caller does not know what its doing.
=cut

sub remove_prefix_from_sqname
{
  my ($self, $sqname) = @_;

  if($sqname !~ m/^\d+\|/) { die "ERROR trying to remove numerical prefix from $sqname, but it doesn't have one"; }
  $sqname =~ s/^\d+\|//;

  return $sqname;
}

#-------------------------------------------------------------------------------

=head2 clone_msa

  Title     : clone_msa
  Incept    : EPN, Thu Nov 21 09:38:23 2013
  Usage     : $newmsaObject = $msaObject->clone_msa()
  Function  : Creates a new MSA, a duplicate of $self.
  Args      : None
  Returns   : $new_msa: a new Bio::Easel::MSA object, a duplicate of $self

=cut

sub clone_msa
{
  my ($self) = @_;

  $self->_check_msa();

  my $new_esl_msa = _c_clone_msa($self->{esl_msa});

  my $new_msa = Bio::Easel::MSA->new({
    esl_msa => $new_esl_msa,
  });

  return $new_msa;
}

#-------------------------------------------------------------------------------

=head2 reorder_all

  Title     : reorder_msa_all
  Incept    : EPN, Mon Feb  3 14:32:59 2014
  Usage     : $msaObject->reorder_all
  Function  : Reorder all sequences in an MSA by swapping pointers.
  Args      : $nameorderAR: [0..i..nseq-1] ref to array with names
            :               of sequences in preferred order.
  Returns   : void
  Dies      : If not all sequences are listed exactly once in $nameorderAR.
=cut

sub reorder_all
{
  my ($self, $nameorderAR) = @_;

  $self->_check_msa();
  $self->_check_index();

  my $nseq = $self->nseq();
  if(scalar(@{$nameorderAR}) != $nseq) { croak "ERROR, reorder_all() wrong num seqs in input array"; }

  # initialize idxorderA
  my @idxorderA = ();
  my @coveredA  = (); # coveredA[$i] is '1' if seq $i has already been reordered, else '0'
  my $i;
  for($i = 0; $i < $nseq; $i++) { $coveredA[$i] = 0; }
  for($i = 0; $i < $nseq; $i++) { 
    my $seqidx = _c_get_sqidx($self->{esl_msa}, $nameorderAR->[$i]);
    if($seqidx == -1)           { croak "ERROR, reorder_all() unable to find sequence $nameorderAR->[$i]"; }
    if($coveredA[$seqidx] != 0) { croak "ERROR, reorder_all() has sequence $nameorderAR->[$i] listed twice"; }
    $idxorderA[$i] = $seqidx;
  }

  _c_reorder($self->{esl_msa}, \@idxorderA);

  return;
}

#-------------------------------------------------------------------------------

=head2 sequence_subset

  Title     : sequence_subset
  Incept    : EPN, Thu Nov 14 10:24:50 2013
  Usage     : $newmsaObject = $msaObject->sequence_subset($usemeAR)
  Function  : Create a new MSA containing a subset of the
            : sequences in a passed in MSA. 
            : Keep any sequence with index i if 
            : usemeAR->[i] == 1, else remove it.
            : All gap columns will not be removed from the MSA,
            : caller may want to do that immediately with
            : remove_all_gap_columns().
  Args      : $usemeAR: [0..i..nseq-1] ref to array with value
            :           '1' to keep seq i, '0' to remove it
  Returns   : $new_msa: a new Bio::Easel::MSA object, with 
            :           a subset of the sequences in $self.
=cut

sub sequence_subset
{
  my ($self, $usemeAR) = @_;

  $self->_check_msa();

  my $new_esl_msa = _c_sequence_subset($self->{esl_msa}, $usemeAR);

  # create new Bio::Easel::MSA object from $new_esl_msa
  my $new_msa = Bio::Easel::MSA->new({
    esl_msa => $new_esl_msa,
  });

  return $new_msa;
}


#-------------------------------------------------------------------------------

=head2 sequence_subset_given_names

  Title     : sequence_subset_given_names
  Incept    : EPN, Tue Feb  4 09:17:37 2014
  Usage     : $newmsaObject = $msaObject->sequence_subset_given_names($nameAR)
  Function  : Create a new MSA containing a subset of the
            : sequences in a passed in MSA. 
            : Keep any sequence with name listed in @{$nameAR}
            : All gap columns will not be removed from the MSA,
            : caller may want to do that immediately with
            : remove_all_gap_columns().
  Args      : $nameAR: ref to array with list of names of seqs to keep
  Returns   : $new_msa: a new Bio::Easel::MSA object, with 
            :           a subset of the sequences in $self.
=cut

sub sequence_subset_given_names
{
  my ($self, $nameAR) = @_;

  $self->_check_msa();
  $self->_check_index();

  # step 1: determine which sequences to keep
  my @usemeA = ();
  my $orig_nseq = $self->nseq();
  my $sub_nseq  = scalar(@{$nameAR});
  my $i;
  for($i = 0; $i < $orig_nseq; $i++) { $usemeA[$i] = 0; }
  for($i = 0; $i < $sub_nseq;  $i++) { 
    my $seqidx = _c_get_sqidx($self->{esl_msa}, $nameAR->[$i]);    
    if($seqidx == -1)         { croak "ERROR, sequence_subset_and_reorder() unable to find sequence $nameAR->[$i]"; }
    if($usemeA[$seqidx] != 0) { croak "ERROR, sequence_subset_and_reorder() has sequence $nameAR->[$i] listed twice"; }
    $usemeA[$seqidx] = 1; 
  }
  my $new_esl_msa = _c_sequence_subset($self->{esl_msa}, \@usemeA);

  # create new Bio::Easel::MSA object from $new_esl_msa
  my $new_msa = Bio::Easel::MSA->new({
    esl_msa => $new_esl_msa,
  });

  return $new_msa;
}

#-------------------------------------------------------------------------------

=head2 sequence_subset_and_reorder

  Title     : sequence_subset_and_reorder
   Incept    : EPN, Tue Feb  4 08:54:13 2014
  Usage     : $newmsaObject = $msaObject->sequence_subset_and_reorder($nameorderAR)
  Function  : Create a new MSA containing a subset of the
            : sequences in a passed in MSA reordered to
            : the order in @{$nameorderAR}. 
            : @{$nameorderAR} contains a subset of the sequences
            : in the MSA with no duplicates.
            : All gap columns will not be removed from the MSA,
            : caller may want to do that immediately with
            : remove_all_gap_columns().
  Args      : $nameorderAR: names of sequences to put in subset in desired order.
  Returns   : $new_msa: a new Bio::Easel::MSA object, with 
            :           a subset of the sequences in $self,
            :           reordered to the order in @{$nameorderAR}.
=cut

sub sequence_subset_and_reorder
{
  my ($self, $nameorderAR) = @_;

  my $new_msa = $self->sequence_subset_given_names($nameorderAR);
  $new_msa->reorder_all($nameorderAR);

  return $new_msa;
}
#-------------------------------------------------------------------------------

=head2 column_subset

  Title     : column_subset
  Incept    : EPN, Thu Nov 14 10:24:50 2013
  Usage     : $msaObject->column_subset($usemeAR)
  Function  : Remove a subset of columns from an MSA.
            : If the column for one half of a SS_cons basepair is 
            : removed but not the other half, the basepair
            : will be removed from SS_cons.
  Args      : $usemeAR: [0..i..alen-1] ref to array with value
            :           '1' to keep column i, '0' to remove it
  Returns   : void
=cut

sub column_subset
{
  my ($self, $usemeAR) = @_;

  $self->_check_msa();
  _c_column_subset($self->{esl_msa}, $usemeAR);

  return;
}

#-------------------------------------------------------------------------------

=head2 column_subset_rename_nse

  Title     : column_subset_rename_nse
  Incept    : EPN, Thu Apr 17 09:59:48 2014
  Usage     : $msaObject->column_subset_rename_nse($usemeAR)
  Function  : Remove a subset of columns from an MSA and
            : add /start-end to the end of all of the names
            : in the alignment. All removed residues must be at terminii 
            : (no 'internal' residues can be removed). 
            :
            : For example, imagine a 3 seq alignment:
            : seq1/5-9   AAAAA
            : seq2/12-13 --AA-
            : seq3       AABAA
            : with a @{$usemeAR} of (0, 0, 1, 1, 0).
            :
            : The returned alignment would be:
            : seq1/5-9/3-4    AA
            : seq2/12-13/1-2  AA
            : seq3/3-4        BA
            : 
            : If ($do_update == 1) the behavior of this function
            : changes to updating any sequences that are already in
            : name/start-end format so that '/start-end' 
            : are consistent with removed residues at the alignment
            : ends. In the above example, the returned alignment
            : would be:
            : seq1/7-8    AA
            : seq2/12-13  AA
            : seq3        BA
            :
            : Note the first sequence has been renamed, the second
            : has not because no residues were removed. The third
            : did have residues removed but it is not in 
            : "name/start-end" format so it was not renamed.
            : 
            :
  Dies      : If any internal residues (non-terminii) are going to be removed.
            :
  Args      : $usemeAR: [0..i..alen-1] ref to array with value
            :           '1' to keep column i, '0' to remove it
  Returns   : void
=cut

sub column_subset_rename_nse
{
  my ($self, $usemeAR, $do_update) = @_;
  my $sub_name = "column_subset_rename_nse";

  $self->_check_msa();
  if(! defined $do_update) { 
    $do_update = 0; 
  }

  # find first and final position we'll include
  my $apos;  # counter over alignment positions
  my $nseq = $self->nseq();
  my $spos = 0;
  my $epos = $self->alen() - 1;

  while($usemeAR->[$spos] == 0 && $spos < $epos) { $spos++; }
  while($usemeAR->[$epos] == 0 && $epos > 1)     { $epos--; }
  if($epos < $spos) { croak "ERROR in $sub_name, trying to remove all columns"; }

  $spos++; # to fix off-by-one; spos is now 1..alen
  $epos++; # to fix off-by-one; epos is now 1..alen

  for(my $i = 0; $i < $nseq; $i++) { 
    my $orig_name = $self->get_sqname($i);
    my ($is_nse, $name, $start, $end, $strand) = $self->_sqname_nse_breakdown($i);
    if((! $do_update) || (! $is_nse)) { # disregard whatever start-end coordinates are in the nse
      $start = 1;
      $end   = $self->get_sqlen($i);
    }
    # determine what the new name will be
    for($apos = 1; $apos < $spos; $apos++) {
      if($self->is_residue($i, $apos)) { 
        if(($strand == 1) || (! $do_update) || (! $is_nse)) { $start++; } # forward strand
        else                                                { $start--; } # reverse strand
      }
    }
    for($apos = $self->alen(); $apos > $epos; $apos--) {
      if($self->is_residue($i, $apos)) { 
        if(($strand == 1) || (! $do_update) || (! $is_nse)) { $end--; } # forward strand
        else                                                { $end++; } # reverse strand
      }
    }
    # check for any internal residues being removed (and croak if we find any)
    for($apos = $spos; $apos <= $epos; $apos++) { 
      if($usemeAR->[($apos-1)] == 0) { # remember off-by-one: usemeA is 0..alen-1 which apos, spos and epos are 1..alen
        if($self->is_residue($i, $apos)) { 
          croak("ERROR in $sub_name, trying to remove internal residue for sequence $i ($orig_name) at position $apos"); 
        }
      }
    }
    # rename the sequence with by either appending start-end (if ! $do_update) or 
    # rewriting start-end (if ! $do_append && $is_nse)
    if(! $do_update) { 
      $self->set_sqname($i, $orig_name."/".$start."-".$end); 
    }
    elsif($is_nse) { # update start and end
      $self->set_sqname($i, $name."/".$start."-".$end); 
    }
  }

  _c_column_subset($self->{esl_msa}, $usemeAR);

  return;
}

#-------------------------------------------------------------------------------

=head2 remove_all_gap_columns

  Title     : remove_all_gap_columns
  Incept    : EPN, Thu Nov 14 13:39:42 2013
  Usage     : $msaObject->remove_all_gap_columns
  Function  : Remove all gap columns from an MSA.
            : If the column for one half of a SS_cons basepair is 
            : removed but not the other half, the basepair
            : will be removed from SS_cons.
  Args      : $consider_rf: '1' to not delete any nongap RF column, else '0'
  Returns   : void
  Dies      : upon an error with croak
=cut

sub remove_all_gap_columns
{
  my ($self, $consider_rf) = @_;

  $self->_check_msa();

  _c_remove_all_gap_columns($self->{esl_msa}, $consider_rf);

  return;
}

#-------------------------------------------------------------------------------

=head2 remove_rf_gap_columns

  Title     : remove_rf_gap_columns
  Incept    : EPN, Thu Nov 21 10:07:07 2013
  Usage     : $msaObject->remove_rf_gap_columns
  Function  : Remove any column from an MSA that is a gap (exists in $gapstr)
            : in the GC RF annotation of the MSA.
  Args      : $gapstr: string of characters to consider as gaps,
            :             if undefined we use '.-~'
  Returns   : void
  Dies      : upon an error with croak
=cut
    
sub remove_rf_gap_columns
{
  my ($self, $gapstr) = @_;

  $self->_check_msa();
  if(! defined $gapstr) { $gapstr = ".-~"; }
  
  if(! $self->has_rf) { croak "Trying to remove RF gap columns, but no RF annotation exists in the MSA"; }
  my $rf = $self->get_rf;
  my @rfA = split("", $rf);
  my $rflen = scalar(@rfA);
  if($self->alen != $rflen) { croak "RF length $rflen not equal to alignment length"; }

  my @usemeA = ();
  for(my $apos = 0; $apos < $rflen; $apos++) { 
    $usemeA[$apos] = ($rfA[$apos] =~ m/[\Q$gapstr\E]/) ? 0 : 1;
  }      
  
  _c_column_subset($self->{esl_msa}, \@usemeA);
  
  return;
}

#-------------------------------------------------------------------------------

=head2 find_divergent_seqs_from_subset

  Title     : find_divergent_seqs_from_subset
  Incept    : EPN, Thu Nov 21 08:41:06 2013
  Usage     : $msaObject->find_divergent_seqs_from_subset
  Function  : Given a subset of sequences, find all other sequences
            : not in the subset that are <= $id_thr fractionally
            : identical to *all* seqs in the subset.
  Args      : $subsetAR: [0..$i..$msa->nseq-1] '1' if sequence i is in the subset, else 0
            : $id_thr:   fractional identity threshold
            : $divAR:    FILLED HERE: [0..$i..$msa->nseq-1] ref to array, '1'  if a sequence
            :            is <= $id_thr fractionally identical to all seqs in subset, else 0
            : $nnidxAR:  FILLED HERE: [0..$i..$msa->nseq-1] ref to array, index of nearest
            :            neighbor (index that is '1' in subsetAR) if $divAR->[$i] == 1, else -1
            : $nnfidAR:  FILLED HERE: [0..$i..$msa->nseq-1] ref to array, index of fractional
            :            identity to nearest neighbor, if $divAR->[$i] == 1, else 0.
            : Example: if sequence idx 5 is $id_thr or less fractionally identical to all
            :          sequences in the subset, but closest to sequence index 11 at 0.73,
            :          then $divAR->[5] = 1, $nnidxAR->[5] = 11, $nnfidAR->[5] = 0.73.
  Returns   : Number of divergent seqs found. This will also be the size of @{$divAR}, @{$nnidxAR} and @{$nnfidAR}
  Dies      : if no sequences exist in $subsetAR, or any indices are invalid
            : with croak
=cut

sub find_divergent_seqs_from_subset
{
  my ($self, $subsetAR, $id_thr, $divAR, $nnidxAR, $nnfidAR) = @_;

  $self->_check_msa();

  my $nseq = $self->nseq;
  my $ndiv = 0;
  my $nsubset = 0;
  for(my $i = 0; $i < $self->nseq; $i++) { 
    my $iamdivergent = 0;
    my $maxid  = -1.;
    my $maxidx = -1;
    if(! $subsetAR->[$i]) { 
      $iamdivergent = 1; # until proven otherwise
      for(my $j = 0; $j < $self->nseq; $j++) {
        if($subsetAR->[$j]) { 
          my $id = _c_pairwise_identity($self->{esl_msa}, $i, $j);
          if($id > $id_thr) { $iamdivergent = 0; $j = $self->nseq+1; } # setting j this way breaks us out of the loop
          if($id > $maxid)  { $maxidx = $j; $maxid = $id; }
        }
      }
    }
    else { 
      $nsubset++; 
    }
    if($iamdivergent) { 
      if(defined $divAR)   { $divAR->[$i]   = 1; }
      if(defined $nnidxAR) { $nnidxAR->[$i] = $maxidx; }
      if(defined $nnfidAR) { $nnfidAR->[$i] = $maxid;  }
      $ndiv++;
    }
    else { 
      if(defined $divAR)   { $divAR->[$i]   = 0;  }
      if(defined $nnidxAR) { $nnidxAR->[$i] = -1; }
      if(defined $nnfidAR) { $nnfidAR->[$i] = 0.; }
    }
  }

  if($nsubset == 0) { die "ERROR in find_most_divergent_seq_from_subset(), no seqs in subset"; }
  return $ndiv;
}


#-------------------------------------------------------------------------------

=head2 find_most_divergent_seq_from_subset

  Title     : find_most_divergent_seq_from_subset
  Incept    : EPN, Thu Nov 21 08:41:06 2013
  Usage     : $msaObject->find_most_divergent_seq_from_subset
  Function  : Given a subset of sequences, find all other sequences
            : not in the subset that are <= $id_thr fractionally
            : identical to *all* seqs in the subset.
  Args      : $subsetAR: [0..$i..$msa->nseq-1] '1' if sequence i is in the subset, else 0
  Returns   : $idx: Index of sequence in $msa that is most divergent from all seqs in
            :       subsetAR, that is, the sequence for which the fractional identity
            :       to its closest neighbor in subsetAR is minimized.
            : $fid: fractional identity of idx to its closest neighbor in msa
            : $nnidx: idx of <$idx>s nearest neighbor in $msa
  Dies      : if no sequences exist in $subsetAR, or any indices are invalid
            : with croak
=cut

sub find_most_divergent_seq_from_subset
{
  my ($self, $subsetAR) = @_;

  $self->_check_msa();
  my $nsubset = 0;

  my $nseq = $self->nseq;
  my $min_max_id = 1.0;
  my $ret_idx = -1;
  my $ret_nnidx = -1;
  for(my $i = 0; $i < $self->nseq; $i++) { 
    if(! $subsetAR->[$i]) { 
      my $max_id = 0.;
      my $max_idx = -1;
      for(my $j = 0; $j < $self->nseq; $j++) {
        if($subsetAR->[$j]) { 
          my $id = _c_pairwise_identity($self->{esl_msa}, $i, $j);
          if($id > $min_max_id) { $j = $self->nseq+1; } # setting j this way breaks us out of the loop
          if($id > $max_id)     { $max_id = $id; $max_idx = $j; }
        }
      }
      if($max_id < $min_max_id) { 
        $ret_idx    = $i;
        $min_max_id = $max_id;
        $ret_nnidx  = $max_idx;
      }
    }
    else { 
      $nsubset++;
    }
  }

  if($nsubset == 0) { die "ERROR in find_most_divergent_seq_from_subset(), no seqs in subset"; }

  return ($ret_idx, $min_max_id, $ret_nnidx);
}

#-------------------------------------------------------------------------------

=head2 avg_min_max_pid_to_seq

  Title    : avg_min_max_pid_to_seq
  Incept   : EPN, Fri Nov 22 08:53:56 2013
  Usage    : $msaObject->avg_min_max_pid_to_seq($i);
  Function : Calculates the average, minimum and maximum 
           : fractional identity of seq $idx to all other seqs.
           : If optional parameter, $usemeAR is passed in
           : then only consider sequences $j for which
           : $usemeAR->[$j] is '1' (except $idx even if
           : $usemeAR->[$idx] is '1').
  Args     : $idx:     index of sequence we want avg/min/max pid to
           : $usemeAR: OPTIONAL: if defined: 
           :           [0..$j..nseq-1]: '1' if we should consider
           :           seq $j in calculation of avg/min/max.
  Returns  : $avg_pid: average fractional id b/t $idx and all other seqs
           : $min_pid: minimum fractional id b/t $idx and all other seqs
           : $min_idx: index of seq that gives $min_pid to $idx
           : $max_pid: minimum fractional id b/t $idx and all other seqs
           : $max_idx: index of seq that gives $max_pid to $idx

=cut

sub avg_min_max_pid_to_seq {
  my ($self, $idx, $usemeAR) = @_;
  
  my $pid;
  my $avg_pid = 0.;
  my $n = 0;
  my $min_pid = 1.1;
  my $min_idx = -1;
  my $max_pid = -1.;
  my $max_idx = -1;

  $self->_check_msa();

  for(my $i = 0; $i < $self->nseq; $i++) { 
    if($i != $idx && (! defined $usemeAR || $usemeAR->[$i])) { 
      $pid = _c_pairwise_identity($self->{esl_msa}, $idx, $i); # get fractional identity
      if($pid < $min_pid) { $min_pid = $pid; $min_idx = $i; }
      if($pid > $max_pid) { $max_pid = $pid; $max_idx = $i; }
      $avg_pid += $pid;
      $n++;
    }
  }
  if($n == 0) { croak "ERROR Bio::Easel::MSA::avg_min_max_pid_to_seq(): no sequences to compare seq $idx to"; }
  $avg_pid /= $n;

  return ($avg_pid, $min_pid, $min_idx, $max_pid, $max_idx);
}


#-------------------------------------------------------------------------------

=head2 create_from_string

  Title     : create_from_string
  Incept    : EPN, Fri Nov 29 07:03:12 2013
  Usage     : $newmsaObject = Bio::Easel::MSA::create_from_string($msa_str, $format)
  Function  : Create a new MSA from a string that is a properly 
            : formatted MSA in format <$format>. If $format is undefined
            : we will use Easels format autodetection capability.
            : If <$do_digitize> we will digitize the alignment before
            : returning, if this is undefined, we do it anyway since
            : most of the BioEasel MSA code requires a digitized MSA.
            : 
  Args      : $msa_str:     the string that is an MSA
            : $format:      string defining format of $msa_str.
            :               valid format strings are: 
            :               "stockholm", "pfam", "a2m", "phylip", "phylips", "psiblast",
            :               "selex", "afa", "clustal", "clustallike", "unknown", or undefined
            : $abc:         string defining alphabet of MSA, valid options:
            :               "amino", "rna", "dna", "coins", "dice", "custom"
            : $do_digitize: '1' to digitize alignment, '0' not do, use '1' unless you know 
            :               what you are doing.
  Returns   : $new_msa: a new Bio::Easel::MSA object, created
            :           from $msa_str
=cut

sub create_from_string
{
  my ($msa_str, $format, $abc, $do_digitize) = @_;

  if(! defined $format) { 
    $format = "unknown";
  }
  if(! defined $abc) { 
    croak "ERROR, alphabet is undefined in create_from_string()"; 
  }
  if($abc ne "amino" && $abc ne "rna" && $abc ne "dna" && $abc ne "coins" && $abc ne "dice" && $abc ne "custom") { 
    croak ("ERROR, alphabet $abc is invalid, valid options are \"amino\", \"rna\", \"dna\", \"coins\", \"dice\", and \"custom\"");
  }
  if(! defined $do_digitize) { # default to TRUE
    $do_digitize = 1; 
  }

  my $new_esl_msa = _c_create_from_string($msa_str, $format, $abc, $do_digitize);

  # create new Bio::Easel::MSA object from $new_esl_msa
  my $new_msa = Bio::Easel::MSA->new({
    esl_msa => $new_esl_msa,
  });

  return $new_msa;
}

#-------------------------------------------------------------------------------

=head2 is_residue

  Title     : is_residue
  Incept    : EPN, Fri Nov 29 17:05:44 2013
  Usage     : $msaObject->is_residue($sqidx, $apos)
  Function  : Return '1' if alignment position $apos of sequence $sqidx
            : is a residue, and '0' if not.
  Args      : $sqidx:   sequence index in MSA
            : $apos:    alignment position [1..alen]
  Returns   : '1' if position $apos of $sqidx is a residue, else '0'
  Dies      : with 'croak' if sequence $sqidx or apos $apos is invalid
=cut

sub is_residue
{
  my ($self, $sqidx, $apos) = @_;

  $self->_check_msa();
  $self->_check_sqidx($sqidx);
  $self->_check_ax_apos($apos);

  return _c_is_residue($self->{esl_msa}, $sqidx, $apos);
}

#-------------------------------------------------------------------------------

=head2 capitalize_based_on_rf

  Title     : capitalize_based_on_rf
  Incept    : EPN, Tue Feb 18 10:44:11 2014
  Usage     : $msaObject->capitalize_based_on_rf
  Function  : Set all residues in nongap RF columns as uppercase,
            : and all gap characters ('.-_') to '-'. Set all residues
            : in gap RF columns to lowercase and all gap characters
            : '.-_' to '.'.
  Args      : none
  Returns   : void
  Dies      : if RF annotation does not exist, or alignment is not in text mode.
=cut

sub capitalize_based_on_rf
{
  my ($self) = @_;

  _c_capitalize_based_on_rf($self->{esl_msa});

  return;
}

#-------------------------------------------------------------------------------

=head2 get_all_GF

  Title     : get_all_GF
  Incept    : EPN, Thu May  8 13:40:50 2014
  Usage     : $msaObject->get_all_GF
  Function  : Get all GF annotation for an MSA by filling a passed in hash.
  Args      : none
  Returns   : void
=cut

sub get_all_GF
{
  my ($self, $gfHR) = @_;

  my $ngf = _c_get_gf_num($self->{esl_msa});
  for(my $i = 0; $i < $ngf; $i++) { 
    my $tag       = _c_get_gf_tag($self->{esl_msa}, $i);
    $gfHR->{$tag} = _c_get_gf    ($self->{esl_msa}, $i);
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 most_informative_sequence

  Title     : most_informative_sequence
  Incept    : EPN, Thu May 15 13:16:06 2014
  Usage     : $msaObject->most_informative_sequence
  Function  : Calculate the "most informative sequence" (Freyhult, Moulton and Gardner, 2005) 
            : Taken from pre-2013 Rfam codebase (Rfam/RfamAlign.pm module).
            : Website definition: "Any residue that has
            : a higher frequency than than the background frequency is projected
            : into the IUPAC redundancy codes."
  Args      : $gapthresh: only columns with >= $gapthresh nongaps will be converted to a nongap residue in the most informative sequence 
            : $use_weights: '1' to use weights in the MSA, '0' not to
  Returns   : a string, the most informative sequence
=cut

sub most_informative_sequence
{
  my ($self, $gapthresh, $use_weights) = @_;

  if(! defined $gapthresh)   { $gapthresh = 0.5; }
  if(! defined $use_weights) { $use_weights = 0; }

  return _c_most_informative_sequence($self->{esl_msa}, $gapthresh, $use_weights);
}

#-------------------------------------------------------------------------------

=head2 pos_fcbp

  Title     : pos_fcbp
  Incept    : EPN, Mon May 19 13:23:33 2014
  Usage     : $msaObject->pos_fcbp
  Function  : Calculate the fraction of canonical basepairs for each nongap RF position in a MSA. 
  Args      : none
  Returns   : array of length msa->alen: the fraction of canonical bps
            : at each position, 0. for non-paired positions.
=cut

sub pos_fcbp
{
  my ($self) = @_;

  my @retA = _c_pos_fcbp($self->{esl_msa});
  return @retA;
}

#-------------------------------------------------------------------------------

=head2 pos_covariation

  Title     : pos_covariation
  Incept    : EPN, Tue May 20 09:23:26 2014
  Usage     : $msaObject->pos_covariation
  Function  : Calculate the 'RNAalifold covariation statistic (Lindgreen, Gardner, Krogh, 2006)'
            : for each basepair in an alignment and return as an array [0..alen-1].
  Args      : none
  Returns   : array of length msa->alen: the covariation statistic
            : at each position, 0. for non-paired positions.
=cut

sub pos_covariation
{
  my ($self) = @_;

  my @retA = _c_pos_covariation($self->{esl_msa});
  return @retA;
}

#-------------------------------------------------------------------------------

=head2 pos_entropy

  Title     : pos_entropy
  Incept    : EPN, Tue May 20 10:44:33 2014
  Usage     : $msaObject->pos_entropy
  Function  : Calculate and return the entropy at each position of an msa.
  Args      : $use_weights: '1' to use weights in the MSA, '0' not to
  Returns   : array of length msa->alen: the entropy at each posn
=cut

sub pos_entropy
{
  my ($self, $use_weights) = @_;

  if(! defined $use_weights) { $use_weights = 0; }

  my @retA = _c_pos_entropy($self->{esl_msa}, $use_weights);

  return @retA;
}

#-------------------------------------------------------------------------------

=head2 pos_conservation

  Title     : pos_conservation
  Incept    : EPN, Tue May 20 15:00:12 2014
  Usage     : $msaObject->pos_conservation
  Function  : Calculate and return the 'sequence conservation' at each position of an msa.
            : 'sequence conservation' of a position is the maximum frequency of any
            :  residue in a column, where frequency is number of occurences divided by
            :  number of sequences (so no column with >=1 gap can have a conservation of 1.0).
            :  And all gap columns have a conservation of 0.0.
  Args      : $use_weights: '1' to use weights in the MSA, '0' not to
  Returns   : array of length msa->alen: the 'sequence conservation' at each posn
=cut

sub pos_conservation
{
  my ($self, $use_weights) = @_;

  if(! defined $use_weights) { $use_weights = 0; }

  my @retA = _c_pos_conservation($self->{esl_msa}, $use_weights);

  return @retA;
}

#-------------------------------------------------------------------------------

=head2 remove_gap_rf_basepairs

  Title     : remove_gap_rf_basepairs
  Incept    : EPN, Fri Jan 29 16:19:17 2016
  Usage     : $msaObject->remove_gap_rf_basepairs
  Function  : Remove any basepair (i,j) (by setting both positions to a '.')
            : in MSA->SS_cons for which exactly one or both of 
            : i and j maps to a gap in the RF annotation.
            : This works with pseudoknots. 
  Args      : $do_wussify: '1' to convert SS_cons to full WUSS notation after removing gap-RF basepairs, '0' not to
  Returns   : void, msa->ss_cons is updated 
  Dies      : if msa->ss_cons is inconsistent
=cut

sub remove_gap_rf_basepairs
{
  my ($self, $do_wussify) = @_;

  _c_remove_gap_rf_basepairs($self->{esl_msa}, $do_wussify);

  return;
}

#-------------------------------------------------------------------------------

=head2 aligned_to_unaligned_pos

  Title     : aligned_to_unaligned_pos
  Incept    : EPN, Thu Jul 14 15:31:16 2016
  Usage     : $msaObject->aligned_to_unaligned_pos($sqidx, $apos)
  Function  : Return the unaligned position $uapos [1..ualen] of 
            : sequence $sqidx that is aligned at position $apos 
            : of the MSA.
            :
            : $apos could be a gap for $sqidx. In this case, the behavior
            : depends on the value of the argument $do_after. If $do_after is
            : '0' or undefined, then:
            :    - return $uapos for alignment position $ret_apos, where $ret_apos
            :      is not a gap for $sqidx and $ret_apos is the highest possible
            :      value that is less than $apos.
            :    - if all alignment positions 1..$apos are gaps for $sqidx
            :      we return -1 for both $uapos and for $ret_apos.
            :
            : If $do_after is '1', then:
            :    - return $uapos for alignment position $ret_apos, where $ret_apos
            :      is not a gap for $sqidx and $ret_apos is the lowest possible
            :      value that is greater than $apos.
            :    - if all alignment positions $apos..$alen are gaps for $sqidx
            :      we return -1 for both $uapos and for $ret_apos.
            : 
  Args      : $sqidx:   index of sequence we are interested in
            : $apos:     alignment position we are interested it
            : $do_after: '1' to return $ret_apos > $apos if $apos is 
            :            a gap, '0' to return $ret_apos < $apos if 
            :            $apos is a gap, can be undef -- treated as 0.
  Returns   : $uapos:    unaligned position that aligns at $ret_apos,
            :            can be -1 in special circumstances (see 'Function'
            :            section above).
            : $ret_apos: the aligned position that $uapos corresponds to,
            :            this will be $apos (passed in) if alignment position
            :            $apos is not a gap. See 'function' section above 
            :            for explanation of what it is if $apos is a gap.
  Dies      : if $apos is < 0 or $apos > $alen
=cut

sub aligned_to_unaligned_pos
{
  my ($self, $sqidx, $apos, $do_after) = @_;

  if(! defined $do_after) { $do_after = 0; }

  $self->_check_msa();
  $self->_check_sqidx($sqidx);
  $self->_check_ax_apos($apos);

  my $sqstring = _c_get_sqstring_aligned($self->{esl_msa}, $sqidx);
  my $ret_apos; # return apos
  my $uapos;    # return value, the unaligned position corresponding to $ret_apos

  # is alignment position $apos a gap in $sqidx?
  my $apos_char = substr($sqstring, $apos-1, 1);
  my $is_gap = ($apos_char =~ m/[a-zA-Z]/) ? 0 : 1;

  if(! $is_gap) { 
    # not a gap, easy case
    # $ret_apos is $apos, 
    # remove all non-alphabetic characters, to get unaligned length
    my $sqstring_to_apos_no_gaps = substr($sqstring, 0, $apos);
    $sqstring_to_apos_no_gaps =~ s/[^a-zA-Z]//g;
    $uapos = length($sqstring_to_apos_no_gaps);
    return ($uapos, $apos);
  }
  else { 
    # $apos is a gap for $sqidx:
    # determine last  position before $apos that is not a gap, if any (if ! $do_after)
    #        or first position after  $apos that is not a gap, if any (if $do_after)
    if(! $do_after) { 
      # $do_after is '0': determine last  position before $apos that is not a gap, if any (if ! $do_after)
      # first check if there are any characters that are not gaps:
      # remove all characters after apos, we don't care about them
      my $sqstring_to_apos = substr($sqstring, 0, $apos);
      if ($sqstring_to_apos =~ /[a-zA-Z]/) {
        # we have at least 1 non-gap
        (my $sqstring_to_apos_no_trailing_gaps = $sqstring_to_apos) =~ s/[^a-zA-Z]*$//;
        $ret_apos = length($sqstring_to_apos_no_trailing_gaps);
        # $ret_apos is now first aligned position before $apos which is not a gap for $seqidx

        (my $sqstring_to_apos_no_gaps = $sqstring_to_apos_no_trailing_gaps) =~ s/[^a-zA-Z]//g; # remove all gaps from sqstring_no_gaps
        $uapos = length($sqstring_to_apos_no_gaps); # length of substr_no_gaps gives us uapos
      }
      else { # no alphabetic characters before $apos, return -1 for both ret_apos and uapos
        $ret_apos = -1;
        $uapos    = -1;
      }
    }
    else { 
      # $do_after is '1': determine first position after  $apos that is not a gap, if any 
      my $sqstring_apos_to_alen = substr($sqstring, $apos-1); # we want to examine from $apos to $alen (remember apos is 1..alen, not 0..alen-1)
      if ($sqstring_apos_to_alen  =~ /[a-zA-Z]/) {
        # we have at least 1 non-gap
        (my $sqstring_apos_to_alen_no_leading_gaps = $sqstring_apos_to_alen) =~ s/^[^a-zA-Z]*//;
        $ret_apos  = $self->alen - length($sqstring_apos_to_alen_no_leading_gaps) + 1; # the +1 is to account for the fact that we didn't remove the first nt
        # $ret_apos is now first aligned position after $apos which is not a gap for $seqidx

        (my $sqstring_apos_to_alen_no_gaps = $sqstring_apos_to_alen_no_leading_gaps) =~ s/[^a-zA-Z]//g; # remove all gaps from sqstring_apos_to_alen_no_gaps
        (my $sqstring_no_gaps = $sqstring) =~ s/[^a-zA-Z]//g;
        $uapos = length($sqstring_no_gaps) - length($sqstring_apos_to_alen_no_gaps) + 1; # again, +1 b/c we didn't remove the first nt;
      }
      else { # no alphabetic characters in the string
        $ret_apos = -1;
        $uapos    = -1;
      }
    }    
    return ($uapos, $ret_apos);
  }
}

#-------------------------------------------------------------------------------

=head2 rfpos_to_aligned_pos

  Title     : rfpos_to_aligned_pos
  Incept    : EPN, Mon Jul 18 15:11:02 2016
  Usage     : $msaObject->rfpos_to_aligned_pos($rfpos)
  Function  : Return the alignment position corresponding to RF position
            : (nongap in GC RF annotation) $rfpos.
            :
  Args      : $rfpos:  RF position we are interested in
            : $gapstr: string of characters to consider as gaps,
            :          if undefined we use '.-~'
  Returns   : $apos:   alignment position (1..$alen) that $rfpos corresponds
            :          to
  Dies      : if $rfpos is < 0 or $rfpos > $rflen (number of nongap RF positions)
            : if $self->{esl_msa} does not have RF annotation
=cut

sub rfpos_to_aligned_pos
{
  my ($self, $rfpos, $gapstr) = @_;

  if(! defined $gapstr) { $gapstr = ".-~"; }

  $self->_check_msa();
  if(! $self->has_rf()) { 
    croak "In rfpos_to_aligned_pos, but MSA does not have RF annotation";
  }

  return _c_rfpos_to_aligned_pos($self->{esl_msa}, $rfpos, $gapstr);
}  

#-------------------------------------------------------------------------------

=head2 get_pp_avg

  Title    : get_pp_avg
  Incept   : EPN, Mon Aug 29 15:38:37 2016
  Usage    : $msaObject->get_pp_avg()
  Function : Return the average posterior probability of an aligned sequence
           : for positions spos to epos. 
  Args     : <idx>:  index of sequence you want avg PP for [0..nseq-1]
           : <spos>: first aligned position you want avg PP for (pass 1 for first position) [1..alen]
           : <epos>: final aligned position you want avg PP for (pass msa->alen for final position) [1..alen]
  Returns  : two values:
           :   1) average aligned posterior probability annotation for sequence index idx from aligned positions spos..epos
           :   2) number of nongap positions for sequence index idx from aligned positions spos..epos

=cut

sub get_pp_avg { 
  my ( $self, $idx, $spos, $epos ) = @_;

  $self->_check_msa();
  $self->_check_sqidx($idx);
  $self->_check_ppidx($idx);
  $self->_check_ax_apos($spos);
  $self->_check_ax_apos($epos);

  if($spos > $epos) { croak "ERROR in get_pp_avg(), spos > epos ($spos > $epos)"; }

  my $full_ppstring = _c_get_ppstring_aligned( $self->{esl_msa}, $idx );
  my $pplen    = $epos-$spos+1;
  my $ppstring = substr($full_ppstring, $spos-1, $pplen);
  
  my ($ppavg, $ppct) = return Bio::Easel::MSA->get_ppstr_avg($ppstring);
}

#-------------------------------------------------------------------------------

=head2 get_ppstr_avg

  Title    : get_ppstr_avg
  Incept   : EPN, Wed Jan 29 09:45:37 2020
  Usage    : Bio::Easel::MSA::get_ppstr_avg($ppstr)
  Function : Return the average posterior probability of a posterior probability
           : string, potentially with gaps.
  Args     : <ppstr>:  string of posterior probability values, possible with gaps (.)
  Returns  : two values:
           :   1) average aligned posterior probability annotation for sequence index idx from aligned positions spos..epos
           :   2) number of nongap positions for sequence index idx from aligned positions spos..epos

=cut

sub get_ppstr_avg { 
  my ( $caller, $ppstr ) = @_;

  my $pplen = length($ppstr);
  my @pp_A = split("", $ppstr);
  my $ppavg = 0.; # sum, then average, of all posterior probability values
  my $ppct  = 0;  # number of nongap posterior probability values
  for(my $ppidx = 0; $ppidx < $pplen; $ppidx++) { 
    my $ppval = $pp_A[$ppidx];
    if   ($ppval eq ".") { ; } # do nothing 
    elsif($ppval eq "*") { $ppavg += 0.975; $ppct++; }
    elsif($ppval eq "9") { $ppavg += 0.9;   $ppct++; }
    elsif($ppval eq "8") { $ppavg += 0.8;   $ppct++; }
    elsif($ppval eq "7") { $ppavg += 0.7;   $ppct++; }
    elsif($ppval eq "6") { $ppavg += 0.6;   $ppct++; }
    elsif($ppval eq "5") { $ppavg += 0.5;   $ppct++; }
    elsif($ppval eq "4") { $ppavg += 0.4;   $ppct++; }
    elsif($ppval eq "3") { $ppavg += 0.3;   $ppct++; }
    elsif($ppval eq "2") { $ppavg += 0.2;   $ppct++; }
    elsif($ppval eq "1") { $ppavg += 0.1;   $ppct++; }
    elsif($ppval eq "0") { $ppavg += 0.025; $ppct++; }
    else { croak "ERROR in get_ppstr_avg(), unexpected PP value of $ppval"; }
  }
  if($ppct > 0) { 
    $ppavg /= $ppct; 
  }
  return ($ppavg, $ppct);
}

#-------------------------------------------------------------------------------

=head2 DESTROY

  Title    : DESTROY
  Incept   : EPN, Mon Jan 28 10:09:55 2013
  Usage    : $msaObject->DESTROY()
  Function : Frees an MSA object
  Args     : none
  Returns  : void

=cut

#-------------------------------------------------------------------------------

sub DESTROY {
  my ($self) = @_;

  _c_destroy( $self->{esl_msa} );
  return;
}


#############################
# Internal helper subroutines
#############################

#-------------------------------------------------------------------------------

=head2 _check_msa

  Title    : _check_msa
  Incept   : EPN, Sat Feb  2 13:42:27 2013
  Usage    : $msaObject->_check_msa()
  Function : Reads msa only if it is currently undefined
  Args     : none
  Returns  : void

=cut

sub _check_msa {
  my ($self) = @_;

  if ( !defined $self->{esl_msa} ) {
    $self->read_msa();
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_sqidx

  Title    : _check_sqidx
  Incept   : EPN, Sat Feb  2 13:46:08 2013
  Usage    : $msaObject->_check_sqidx($idx)
  Function : Check if $idx is in range 0..nseq-1,
             if not, croak.
  Args     : $idx
  Returns  : void

=cut

sub _check_sqidx {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  my $nseq = $self->nseq;
  if ( $idx < 0 || $idx >= $nseq ) {
    croak (sprintf("invalid sequence index %d (must be [0..%d])", $idx, $nseq-1));
  }
  return;
}
#-------------------------------------------------------------------------------

=head2 _check_ppidx

  Title    : _check_ppidx
  Incept   : EPN, Mon Jul  7 09:14:06 2014
  Usage    : $msaObject->_check_ppidx($idx)
  Function : Check if $idx is in range 0..nseq-1,
           : and that the MSA has PP annoation for $idx
  Args     : $idx
  Returns  : void
  Dies     : via croak if no PP annotation exists for sequence $idx

=cut

sub _check_ppidx {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  my $nseq = $self->nseq;
  if ( $idx < 0 || $idx >= $nseq ) {
    croak (sprintf("invalid sequence index %d (must be [0..%d])", $idx, $nseq));
  }
  if(_c_check_ppidx($self->{esl_msa}, $idx) == 0) { 
    croak (sprintf("no PP annotation for sequence index %d", $idx));
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_saidx

  Title    : _check_saidx
  Incept   : EPN, Fri Feb 19 15:19:55 2021
  Usage    : $msaObject->_check_saidx($idx)
  Function : Check if $idx is in range 0..nseq-1,
           : and that the MSA has SA annoation for $idx
  Args     : $idx
  Returns  : void
  Dies     : via croak if no SA annotation exists for sequence $idx

=cut

sub _check_saidx {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  my $nseq = $self->nseq;
  if ( $idx < 0 || $idx >= $nseq ) {
    croak (sprintf("invalid sequence index %d (must be [0..%d])", $idx, $nseq));
  }
  if(_c_check_saidx($self->{esl_msa}, $idx) == 0) { 
    croak (sprintf("no SA annotation for sequence index %d", $idx));
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_ssidx

  Title    : _check_ssidx
  Incept   : EPN, Fri Feb 19 15:19:58 2021
  Usage    : $msaObject->_check_ssidx($idx)
  Function : Check if $idx is in range 0..nseq-1,
           : and that the MSA has SS annoation for $idx
  Args     : $idx
  Returns  : void
  Dies     : via croak if no SS annotation exists for sequence $idx

=cut

sub _check_ssidx {
  my ( $self, $idx ) = @_;

  $self->_check_msa();
  my $nseq = $self->nseq;
  if ( $idx < 0 || $idx >= $nseq ) {
    croak (sprintf("invalid sequence index %d (must be [0..%d])", $idx, $nseq));
  }
  if(_c_check_ssidx($self->{esl_msa}, $idx) == 0) { 
    croak (sprintf("no SS annotation for sequence index %d", $idx));
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_ax_apos

  Title    : _check_ax_apos
  Incept   : EPN, Fri Nov 29 17:09:11 2013
  Usage    : $msaObject->_check_ax_apos($apos)
  Function : Check if $apos is in range 1..alen,
             if not, croak.
  Args     : $apos
  Returns  : void

=cut

sub _check_ax_apos {
  my ( $self, $apos ) = @_;

  $self->_check_msa();
  my $alen = $self->alen;
  if ( $apos < 1 || $apos > $alen ) {
    croak (sprintf("invalid alignment position %d (must be [1..%d])", $apos, $alen));
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_aseq_apos

  Title    : _check_aseq_apos
  Incept   : EPN, Fri Nov 29 17:09:11 2013
  Usage    : $msaObject->_check_aseq_apos($apos)
  Function : Check if $apos is in range 0..alen-1,
             if not, croak.
  Args     : $apos
  Returns  : void

=cut

sub _check_aseq_apos {
  my ( $self, $apos ) = @_;

  $self->_check_msa();
  my $alen = $self->alen;
  if ( $apos < 0 || $apos >= $alen ) {
    croak (sprintf("invalid alignment position %d (must be [0..%d])", $apos, $alen-1));
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_reqd_format

  Title    : _check_reqd_format
  Incept   : EPN, Thu Jul 18 11:06:02 2013
  Usage    : $msaObject->_check_reqd_format()
  Function : Check if $self->{reqdFormat} is a valid format or 'unknown'
           : if not, croak. Also returns fine if self->{reqdFormat} is not
           : defined.
  Args     : none
  Returns  : void

=cut

sub _check_reqd_format { 
  my ( $self ) = @_;

  if(defined $self->{reqdFormat}) { 
    if($self->{reqdFormat} ne "unknown") { # unknown is valid, so we don't actually do the C check 
      _c_check_reqd_format($self->{reqdFormat}); 
    }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _check_index

  Title    : _check_index
  Incept   : EPN, Mon Feb  3 15:17:21 2014
  Usage    : $msaObject->_check_index()
  Function : Check if an MSA has a hash and if not, create one.
  Args     : none
  Returns  : void
  Dies     : If no index exists and unable to create one.

=cut

sub _check_index { 
  my ( $self ) = @_;

  _c_check_index($self->{esl_msa});

  return;
}

#-------------------------------------------------------------------------------

=head2 _sqname_nse_breakdown

  Title    : _sqname_nse_breakdown
  Incept   : EPN, Thu Apr 17 10:05:51 2014
  Usage    : $msaObject->_sqname_nse_breakdown($i)
  Function : Checks if sequence $i name is of format "name/start-end" and if so
           : breaks it down into $n, $s, $e, $str (see 'Returns' section)
  Args     : <sqname>: seqname, possibly of format "name/start-end"
  Returns  : 5 values:
           :   '1' if seqname was of "name/start-end" format, else '0'
           :   $n:   name ("" if seqname does not match "name/start-end")
	   :   $s:   start, maybe <= or > than $e (0 if seqname does not match "name/start-end")
	   :   $e:   end,   maybe <= or > than $s (0 if seqname does not match "name/start-end")
           :   $str: strand, 1 if $s <= $e, else -1
=cut

sub _sqname_nse_breakdown {
  my ( $self, $sqidx ) = @_;
  
  $self->_check_msa();
  my $sqname = $self->get_sqname($sqidx);
  
  my $n;       # sqacc
  my $s;       # start, from seq name (can be > $end)
  my $e;       # end,   from seq name (can be < $start)
  my $str;     # strand, 1 if $start <= $end, else -1

  if($sqname =~ m/^(\S+)\/(\d+)\-(\d+)\s*/) {
    ($n, $s, $e) = ($1,$2,$3);
    $str = ($s <= $e) ? 1 : -1; 
    return (1, $n, $s, $e, $str);
  }
  # if we get here, seq name is not in name/start-end format
  return (0, "", 0, 0, 0);
}

#-------------------------------------------------------------------------------

=head2 _check_all_sqname_nse

  Title    : _check_all_sqname_nse
  Incept   : EPN, Thu Apr 17 10:06:36 2014
  Usage    : $msaObject->_check_all_sqname_nse()
  Function : Check if all sequence names in the msa are in 'name/start-end' format. 
           : If so, return '1', else return '0'.
  Args     : none
  Returns  : '1' if all sequence names are in name/start-end format, else '0'.

=cut

sub _check_all_sqname_nse {
  my ( $self ) = @_;
  my $is_nse;
  
  my $nseq = $self->nseq();
  for(my $i = 0; $i < $nseq; $i++) { 
    ($is_nse, undef, undef, undef, undef) = $self->_sqname_nse_breakdown_c_check_index($i);
    if($is_nse == 0) { return 0; }
  }
  # if we get here, all seq names are in name/start-end format
  return 1;
}


#-------------------------------------------------------------------------------

=head2 _get_nongap_numbering_for_aligned_string

  Title    : _get_nongap_numbering_for_aligned_string
  Incept   : EPN, Fri Jun 11 12:22:30 2021
  Usage    : _get_nongap_numbering_for_aligned_string($aligned_sqstring, $gap_str, $gap_char, $num_str_AR)
  Function : Fill @{$num_str_AR} with strings that given numbering for nongap columns.
           : Example:               AGCGA--GCGACG-GACG.GG
           : Returns: 
           :    @{$num_str_AR->[0]} 00000..000011.1111.11
           :    @{$num_str_AR->[1]} 12345..678901.2345.67
  Args     : $aligned_sqstring: aligned seq string for a sequence or RF (or other)
           : $num_str_AR:       RETURN: filled with N numberings, where N is number of digits in 
           :                    unaligned length of $aligned_sqstring
           : $gap_str:          string with characters that are gaps in $aligned_sqstring (e.g. ".-~";), set to "" 
           :                    to number ALL columns (even gap ones)
           : $gap_char:         character to use for gaps in @{$num_str_AR}
           :
  Returns  : void, fills @{$num_str_AR}

=cut

sub _get_nongap_numbering_for_aligned_string { 
  my ( $aligned_sqstring, $num_str_AR, $gap_str, $gap_char) = @_;

  if(! defined $aligned_sqstring) { croak "In _get_nongap_numbering_for_aligned_string, aligned_sqstring is undefined"; }
  if(! defined $num_str_AR)       { croak "In _get_nongap_numbering_for_aligned_string, num_str_AR is undefined"; }
  if(! defined $gap_str)          { $gap_str  = ".-~"; }
  if(! defined $gap_char)         { $gap_char = "."; }

  chomp $aligned_sqstring;

  # determine max index (number) column
  my $dealigned_sqstring = $aligned_sqstring;
  if($gap_str ne "") { # if $gap_str is "" we'll number ALL columns even gap ones
    $dealigned_sqstring =~ s/[\Q$gap_str\E]//g;
  }
  my $max  = length($dealigned_sqstring);
  my $ndig = length($max);

  # initialize
  @{$num_str_AR} = (); # set to empty
  my $d;              # counter over digits
  my @cur_val_A = (); # [0..$d..$ndig-1] current value for digit $d, $d == 0, 1s place, $d == 1, 10s place, $d == 2 100s place etc.
  for($d = 0; $d < $ndig; $d++) { 
    $num_str_AR->[$d] = "";
    $cur_val_A[$d] = 0;
  }

  my @aligned_sqstring_A = split("", $aligned_sqstring);
  my $i;
  my $uapos = 0; # nongap, unaligned position in sequence 

  for($i = 0; $i < scalar(@aligned_sqstring_A); $i++) { 
    if(($gap_str eq "") || ($aligned_sqstring_A[$i] !~ /[\Q$gap_str\E]/)) { 
      $uapos++;
      my $keep_going = 1;
      my $d = 0;
      # increment 
      while($keep_going) {
        if($d >= $ndig) { croak "In _get_nongap_numbering_for_aligned_string, trying to number column to number above expected max of $max"; }
        $cur_val_A[$d]++;
        if($cur_val_A[$d] == 10) {
          $cur_val_A[$d] = 0;
          $keep_going = 1; # we'll increment $d and keep going (e.g. if we're at ones place and we reach 10, then we bump tens place)
          $d++;
        }
        else { 
          $keep_going = 0;
        }
      }
      for($d = 0; $d < $ndig; $d++) { 
        $num_str_AR->[$d] .= $cur_val_A[$d];
      }
    }
    else { # gap in the sequence
      for($d = 0; $d < $ndig; $d++) { 
        $num_str_AR->[$d] .= $gap_char;
      }
    }
  }

  return;
}

#-------------------------------------------------------------------------------

=head2 _c_read_msa
=head2 _c_write_msa
=head2 _c_nseq
=head2 _c_alen
=head2 _c_get_accession
=head2 _c_set_accession
=head2 _c_get_sqname
=head2 _c_set_sqname
=head2 _c_any_allgap_columns
=head2 _c_average_id
=head2 _c_get_sqlen
=head2 _c_average_sqlen
=head2 _c_addGF
=head2 _c_addGS
=head2 _c_count_msa
=head2 _c_bp_is_canonical
=head2 _c_calc_and_write_bp_stats
=head2 dl_load_flags

=head1 AUTHORS

Eric Nawrocki, C<< <nawrocke at ncbi.nlm.nih.gov> >>
Jody Clements, C<< <clementsj at janelia.hhmi.org> >>
Rob Finn, C<< <rdf at ebi.ac.uk> >>
William Arndt, C<< <warndt at lbl.gov> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-bio-easel at rt.cpan.org>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bio::Easel::MSA


=head1 ACKNOWLEDGEMENTS

Sean R. Eddy is the author of the Easel C library of functions for
biological sequence analysis, upon which this module is based.

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Eric Nawrocki.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
