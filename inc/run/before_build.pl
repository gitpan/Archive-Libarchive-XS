use strict;
use warnings;
use Alien::Libarchive;
use Path::Class qw( file dir );

my $alien = Alien::Libarchive->new;
my $report = '';
my @pathtypes = qw( gname hardlink pathname symlink uname );

my @macros = do { # constants

  # keep any new macros, even if we are doing a dzil build
  # against an old libarchive
  my %macros = (map { chomp; $_ => 1 } file(__FILE__)->parent->parent->file('constants.txt')->slurp, grep { $_ ne 'ARCHIVE_VERSION_STRING' } grep { $_ !~ /H_INCLUDED$/ } $alien->_macro_list);
  sort keys %macros;  
};
file(__FILE__)->parent->parent->file('constants.txt')->spew(join "\n", @macros);

do { # xs
  my $file = file(__FILE__)->parent->parent->parent->file(qw( lib Archive Libarchive XS.xs ))->absolute;
  my @xs = $file->slurp;

  my $buffer;
  
  $buffer .= shift @xs while @xs > 0 && $xs[0] !~ /CONSTANT AUTOGEN BEGIN/;
  $buffer .= "        /* CONSTANT AUTOGEN BEGIN */\n";
  shift @xs while @xs > 0 && $xs[0] !~ /CONSTANT AUTOGEN END/;
  
  foreach my $macro (@macros)
  {
    next if $macro eq 'ARCHIVE_OK';
    $buffer .= "#ifdef $macro\n";
    $buffer .= "        else if(!strcmp(name, \"$macro\"))\n";
    $buffer .= "          RETVAL = $macro;\n";
    $buffer .= "#endif\n";
                      
  }

  $buffer .= shift @xs while @xs > 0 && $xs[0] !~ /PURE AUTOGEN BEGIN/;
  
  $buffer .= "/* PURE AUTOGEN BEGIN */\n";
  $buffer .= "/* Do not edit anything below this line as it is autogenerated\n";
  $buffer .= "and will be lost the next time you run dzil build */\n\n";
  
  foreach my $filter (sort qw( bzip2 compress gzip grzip lrzip lzip lzma lzop none rpm uu xz ))
  {
    $buffer .= "=head2 archive_read_support_filter_$filter\n\n";
    $buffer .= " my \$status = archive_read_support_filter_$filter(\$archive);\n\n";
    $buffer .= "Enable $filter decompression filter.\n\n";
    $buffer .= "=cut\n\n";
    $buffer .= "#if HAS_archive_read_support_filter_$filter\n\n";
    $buffer .= "int\n";
    $buffer .= "archive_read_support_filter_$filter(archive)\n";
    $buffer .= "    struct archive *archive\n\n";
    $buffer .= "#endif\n\n";
  }
  
  foreach my $format (sort qw( 7zip ar cab cpio empty gnutar iso9660 lha mtree rar raw tar xar zip ))
  {
    $buffer .= "=head2 archive_read_support_format_$format\n\n";
    $buffer .= " my \$status = archive_read_support_format_$format(\$archive);\n\n";
    $buffer .= "Enable $format archive format.\n\n";
    $buffer .= "=cut\n\n";
    $buffer .= "#if HAS_archive_read_support_format_$format\n\n";
    $buffer .= "int\n";
    $buffer .= "archive_read_support_format_$format(archive)\n";
    $buffer .= "    struct archive *archive\n\n";
    $buffer .= "#endif\n\n";
  }

  foreach my $filter (sort qw( b64encode bzip2 compress grzip gzip lrzip lzip lzma lzop none uuencode xz ))
  {
    $buffer .= "=head2 archive_write_add_filter_$filter\n\n";
    $buffer .= " my \$status = archive_write_add_filter_$filter(\$archive);\n\n";
    $buffer .= "Add $filter filter\n\n";
    $buffer .= "=cut\n\n";
    $buffer .= "#if HAS_archive_write_add_filter_$filter\n\n";
    $buffer .= "int\n";
    $buffer .= "archive_write_add_filter_$filter(archive)\n";
    $buffer .= "    struct archive *archive\n\n";
    $buffer .= "#endif\n\n";
  }
  
  foreach my $format (sort qw( 7zip ar_bsd ar_svr4 cpio cpio_newc gnutar iso9660 mtree mtree_classic pax pax_restricted shar shar_dump ustar v7tar xar zip old_tar ))
  {
    $buffer .= "=head2 archive_write_set_format_$format(\$archive)\n\n";
    $buffer .= " my \$status = archive_write_set_format_$format(\$archive);\n\n";
    $buffer .= "Set the archive format to $format\n\n";
    $buffer .= "=cut\n\n";
    $buffer .= "#if HAS_archive_write_set_format_$format\n\n";
    $buffer .= "int\n";
    $buffer .= "archive_write_set_format_$format(archive)\n";
    $buffer .= "    struct archive *archive\n\n";
    $buffer .= "#endif\n\n";
    
  }
  
  foreach my $name (@pathtypes)
  {
    use Mojo::Template;
    my $mt = Mojo::Template->new;
    $mt->prepend(qq{my \$name = '$name';\n});
    $buffer .= $mt->render( scalar file(__FILE__)->parent->parent->file(qw( path.xs.template ))->slurp );
  }

  $file->spew($buffer);
};

my %symbols;
do { # symbol list

  if($alien->cflags =~ /-I(\S+)/)
  {
    my $include = dir($1);
    foreach my $line (map { $include->file($_)->slurp } qw( archive.h archive_entry.h ))
    {
      while($line =~ s/\b(archive_[A-Za-z0-9_]+)//)
      {
        $symbols{$1} = 1;
      }
    }
  }
  
  open(my $fh, '<', file(__FILE__)->parent->parent->file('symbols.txt'));
  foreach my $line (<$fh>)
  {
    chomp $line;
    $symbols{$line} = 1;
  }
  close $fh;
  
  my @deprecated = qw(
    archive_read_support_compression_all
    archive_read_support_compression_bzip2
    archive_read_support_compression_compress
    archive_read_support_compression_gzip
    archive_read_support_compression_lzip
    archive_read_support_compression_lzma
    archive_read_support_compression_none
    archive_read_support_compression_program
    archive_read_support_compression_program_signature
    archive_read_support_compression_rpm
    archive_read_support_compression_uu
    archive_read_support_compression_xz
    archive_read_open_file
    archive_read_finish
    archive_write_set_compression_bzip2
    archive_write_set_compression_compress
    archive_write_set_compression_gzip
    archive_write_set_compression_lzip
    archive_write_set_compression_lzma
    archive_write_set_compression_none
    archive_write_set_compression_program
    archive_write_set_compression_xz
    archive_write_open_file
    archive_write_finish
    archive_position_compressed
    archive_position_uncompressed
    archive_compression_name
    archive_compression
    
    archive_entry_set_ino64
    archive_entry_ino64
    archive_entry_stat32
    archive_entry_stat64
  );
  
  delete $symbols{$_} for @deprecated;
  
  my @not_real = qw(
    archive_acl
    archive_read
    archive_read_support_XXX
    archive_write_disk
    archive_read_open_XXX
    archive_platform
    archive_read_disk
    archive_entry_linkresolver
  );
  
  delete $symbols{$_} for @not_real;
  
  my @typedefs = qw(
    archive_entry
    archive_match
    archive_read_callback
    archive_skip_callback
    archive_seek_callback
    archive_write_callback
    archive_open_callback
    archive_close_callback
    archive_switch_callback
  );
  
  delete $symbols{$_} for @typedefs;
  
  file(__FILE__)->parent->parent->file('symbols.txt')->spew(join "\n", sort keys %symbols);
  
  delete $symbols{$_} for grep /_(w|utf8)$/, keys %symbols;
  
  my @wontimplement = qw(
    archive_read_add_callback_data
    archive_read_append_callback_data
    archive_read_prepend_callback_data
    archive_read_set_callback_data2
    archive_read_open_FILE
    archive_read_open_fd
    archive_read_data_into_fd
    archive_read_open_memory2
    archive_write_open_fd
    archive_write_open_FILE
    archive_entry_copy_gname
    archive_entry_copy_hardlink
    archive_entry_copy_pathname
    archive_entry_copy_symlink
    archive_entry_copy_uname
    archive_entry_copy_link
  );

  delete $symbols{$_} for @wontimplement;
};

do {
  use Pod::Abstract;
  use Mojo::Template;
  use JSON qw( to_json );
  my $mt = Mojo::Template->new;
  
  my $pa = Pod::Abstract->load_file(
    file(__FILE__)->parent->parent->parent->file(qw( lib Archive Libarchive XS.xs ))->stringify
  );
  
  $_->detach for $pa->select('//#cut');
  
  my %functions;
  
  foreach my $pod ($pa->children)
  {
    if($pod->pod =~ /^=head2 ([A-Za-z_0-9]+)/)
    {
      my $name = $1;
      if(defined $symbols{$name})
      {
        delete $symbols{$name};
      }
      else
      {
        $report .= "extra: $name\n";
      }
      $functions{$name} = $pod->pod;
      $functions{$name} =~ s/\s+$//;
    }
    else
    {
      die "error parsing " .  $pod->text;
    }
  }
  
  $mt->prepend(qq{
    use JSON qw( from_json );
    my \$functions = from_json(q[} . to_json(\%functions) . qq{]);
    my \$constants = from_json(q[} . to_json(\@macros) . qq{] );
    my \$pathtypes = from_json(q[} . to_json(\@pathtypes) . qq{]);
  });
  
  do {
    my $perl = $mt->render( scalar file(__FILE__)->parent->parent->file(qw( XS.pm.template ))->slurp );
    my $file = file(__FILE__)->parent->parent->parent->file(qw( lib Archive Libarchive XS.pm ))->absolute;
    $file->spew($perl);
  };

  do {
    my $pod = $mt->render( scalar file(__FILE__)->parent->parent->file(qw( Function.pod.template ))->slurp );
    $pod =~ s{L<#(.*?)>}{L<$1|Archive::Libarchive::XS::Function#$1>}g;
    my $file = file(__FILE__)->parent->parent->parent->file(qw( lib Archive Libarchive XS Function.pod ))->absolute;
    $file->spew($pod);
  };

  do {
    my $pod = $mt->render( scalar file(__FILE__)->parent->parent->file(qw( Constant.pod.template ))->slurp );
    my $file = file(__FILE__)->parent->parent->parent->file(qw( lib Archive Libarchive XS Constant.pod ))->absolute;
    $file->spew($pod);
  };
  
  file(__FILE__)->parent->parent->file('functions.txt')->spew(join "\n", sort keys %functions);
};

my $count = 0;

$report .= "\n";

foreach my $symbol (sort keys %symbols)
{
  $report .= "unimplemented: $symbol\n";
  $count ++;
}

$report .= "\ntotal unimplemented symbols: $count\n";

file(__FILE__)->parent->parent->file('report.txt')->spew($report);

