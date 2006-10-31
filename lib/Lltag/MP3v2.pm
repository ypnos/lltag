package Lltag::MP3v2 ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

sub test_MP3Tag {
    my $self = shift ;
    if (not eval { require MP3::Tag ; } ) {
        print "MP3::Tag::ID3v1 does not seem to be available, disabling 'MP3v2' backend.\n"
	    if $self->{verbose_opt} ;
	return -1 ;
    }
    return 0 ;
}

#################################################
# Convert v1 tag to lltag tag name, keep a unique non-null one

sub read_v1_tag {
    my $self = shift ;
    my $values = shift ;
    my $v1_field = shift ;
    my $value = shift ;

    # not needed
    return if $v1_field eq 'parent' or $v1_field eq 'mp3' ;

    # ignore for now, use when we have the list of genres
    return if $v1_field eq 'genreID' ;

    # translate into common field names
    my $field = uc($v1_field) ;
    $field =~ s/YEAR/DATE/ ;
    $field =~ s/TRACK/NUMBER/ ;

    if (grep { $_ =~ $field } @{$self->{field_names}}) {
	if (exists $values->{$field}) {
	    Lltag::Misc::print_warning ("  ", "Duplicated MP3v1 tag '$field', overwriting.") ;
	}
	$values->{$field} = $value
	    if $value ;
    } else {
	Lltag::Misc::print_warning ("  ", "Unrecognized MP3v1 tag '$v1_field', ignoring.") ;
    }
}

#################################################
# Convert v2 tag to lltag tag name, append all non-null ones

sub read_v2_tag {
    my $self = shift ;
    my $values = shift ;
    my $v2_field = shift ;
    my $value = shift ;

    # TODO: restore them too ?
    return if $v2_field eq "Comments -> Description"
	or $v2_field eq "Comments -> encoding"
	or $v2_field eq "Comments -> Language" ;

    my %v2_field_name_translations =
	(
	 "Lead performer(s)/Soloist(s)" => "ARTIST",
	 "Title/songname/content description" => "TITLE",
	 "Album/Movie/Show title" => "ALBUM",
	 "Track number/Position in set" => "NUMBER",
	 "Content type" => "GENRE",
	 "Year" => "DATE",
	 "Comments -> Text" => "COMMENT",
	 ) ;

    # translate into common field names
    my $field ;
    if (exists $v2_field_name_translations{$v2_field}) {
	$field = $v2_field_name_translations{$v2_field} ;
    } else {
	$field = uc($v2_field) ;
    }

    Lltag::Tags::append_tag_value ($self, $values, $field, $value) ;
}

#################################################
# Merge v1 and v2 tags, and deal with conflicts

sub merge_v1_into_v2_tags {
    my $self = shift ;
    my $v2_values = shift ;
    my $v1_values = shift ;

    $v2_values = {}	unless defined $v2_values ;

    # FIXME: need an option to configure all this
    if (defined $v1_values) {
	if (defined $v2_values) {
	    print "  Merging MP3 v1 and v2 tags...\n"
		if $self->{verbose_opt} ;
	} else {
	    $v2_values = {} ;
	}
	foreach my $field (keys %{$v1_values}) {
	    Lltag::Tags::append_tag_value ($self, $v2_values, $field, $v1_values->{$field}) ;
	}
    }

    return $v2_values ;
}

#################################################
# Read both v1 and v2 if they exist and return their merge

sub read_tags {
    my $self = shift ;
    my $file = shift ;

    my $mp3 = MP3::Tag->new ($file) ;
    $mp3->get_tags();

    # Extract ID3v2 first, if it exists
    my $v2_values = undef ;
    if (exists $mp3->{ID3v2}) {
	$v2_values = {} ;
	print "  Found a MP3 v2 tag, reading it...\n"
	    if $self->{verbose_opt} ;
	my $id3v2 = $mp3->{ID3v2} ;
	my $frameIDs_hash = $id3v2->get_frame_ids('truename');
	foreach my $frame (keys %$frameIDs_hash) {
	    my ($info, $name, @infos) = $id3v2->get_frame($frame);
	    unshift @infos, $info ;
	    foreach $info (@infos) {
		if (ref $info) {
		    while(my ($key, $value) = each %$info) {
			read_v2_tag $self, $v2_values, "$name -> $key", $value ;
		    }
		} else {
		    read_v2_tag $self, $v2_values, $name, $info ;
		}
	    }
	}
    }

    # Extract ID3v1 last, if it exists, since v2 is generally preferred
    my $v1_values = undef ;
    if (exists $mp3->{ID3v1}) {
	$v1_values = {} ;
	print "  Found a MP3 v1 tag, reading it...\n"
	    if $self->{verbose_opt} ;
	my $id3v1 = $mp3->{ID3v1} ;
	map { read_v1_tag $self, $v1_values, $_, $id3v1->{$_} } (keys %{$id3v1}) ;
    }

    return merge_v1_into_v2_tags $self, $v2_values, $v1_values ;
}

#################################################
# Set tags

sub set_tags {
    my $self = shift ;
    my $file = shift ;
    my $values = shift ;

    # TODO: dry-run
    # TODO: disable v1 or v2 ?

    my $mp3 = MP3::Tag->new ($file) ;
    $mp3->get_tags();

    # clear existing tags
    if (exists $mp3->{ID3v1}) {
	$mp3->{ID3v1}->remove_tag ;
    }
    if (exists $mp3->{ID3v2}) {
	$mp3->{ID3v2}->remove_tag ;
    }

    # add a new v1 tag
    my $id3v1 = $mp3->new_tag("ID3v1");

    map {
	# warning about unknown v1 tag in verbose mode only, since v2 tag will be ok
	Lltag::Misc::print_warning ("    ", "Cannot set $_ in mp3v1 tags")
	    if $self->{verbose_opt} ;
    } (Lltag::Tags::get_values_non_regular_keys ($self, $values)) ;

    map {
	# only one tag is allowed in v1, use the first one
	my $value = Lltag::Tags::get_tag_unique_value ($self, $values, $_) ;
	# convert to MP3v1 tag name
	my $field = lc($_) ;
	$field =~ s/date/year/ ;
	$field =~ s/number/track/ ;
	# set tag
	$id3v1->$field ($value) ;
    } ( grep { defined $values->{$_} } @{$self->{field_names}} ) ;
    # commit changes
    $id3v1->write_tag () ;

    # add a new v2 tag
    my $id3v2 = $mp3->new_tag("ID3v2");
    my %v2_frame_name_translations =
	(
	 "ARTIST" => "TPE1",
	 "TITLE" => "TIT2",
	 "ALBUM" => "TALB",
	 "NUMBER" => "TRCK",
	 "GENRE" => "TCON",
	 "DATE" => "TYER",
	 ) ;
    map {
	my $frame ;
	if (exists $v2_frame_name_translations{$_}) {
	    $id3v2->add_frame($v2_frame_name_translations{$_}, $values->{$_}) ;
	} elsif ($_ eq "COMMENT") {
	    $id3v2->add_frame("COMM", "", "", $values->{$_}) ;
	} else {
	    print "Don't know what to do with $_\n" ;
	}
    } (keys %{$values}) ;
    # commit changes
    $id3v2->write_tag () ;

}

#################################################
# Initialization

sub new {
    my $self = shift ;

    return undef
	if test_MP3Tag $self ;

    return {
       name => "MP3v2 (using MP3::Tag)",
       type => "mp3",
       extension => "mp3",
       read_tags => \&read_tags,
       set_tags => \&set_tags,
    } ;
}

1 ;