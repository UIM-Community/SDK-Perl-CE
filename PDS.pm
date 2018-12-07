package Nimbus::PDS;

use vars qw($VERSION @ISA @EXPORT);
use Nimbus::API;

require Exporter;
@ISA = qw(Exporter);

# PDS Constant (since 2.1.0)
use constant {
    PDS_PPCH => 8,
	PDS_PPI => 3,
	PDS_PPDS => 24
};

#############################################################
#Export selected functions from Nimbus::API;
#############################################################
@EXPORT = qw (
	nimLog 
	nimLogSet 
	nimLogSetLevel
	PDS_PPCH
	PDS_PPI
	PDS_INT
	PDS_F
	PDS_PCH
	PDS_PDS
	PDS_PPDS
);

$VERSION = '2.1.0';

#############################################################
# Constructor
#############################################################
sub new {
	my ($class, $pds, $cleanup) = @_;
	my $localPds = 0;
	if (!defined($pds)) {
		$pds = pdsCreate();
		$localPds = 1;
	}

	return bless({
		pds => $pds,
		getTableIndex => 0,
		localPds => $localPds + $cleanup || 0
	},ref($class) || $class);
}

#############################################################
#
#############################################################
sub DESTROY {
	my ($self) = @_;
	nimLog (2,"$self: Object is destroyed");
	if ($self->{localPds} == 1) {
		nimLog(3,"$self: Local PDS being removed");
		pdsDelete($self->{pds});
	}
}

#############################################################
#
#############################################################
sub post {
	my ($self, $subject) = @_;
	return 1 if !defined($subject);
	nimLog(3,"PDS::post -  subject: $subject");
	return nimPostMessage($subject, $self->{pds});
}

#############################################################
#
#############################################################
sub dump {
	my ($self) = @_;
	nimLog(4,"PDS::dump");
	pdsDump($self->{pds});	
}

#############################################################
#
#############################################################
sub data {
	my ($self) = @_;
	return $self->{pds};	
}

#############################################################
#
#############################################################
sub remove {
	my ($self, $name) = @_;
	return pdsRemove($self->{pds}, $name);
}

#############################################################
#
#############################################################
sub rewind {
	my ($self) = @_;
	return pdsRewind($self->{pds});
}

#############################################################
#
#############################################################
sub reset {
	my ($self) = @_;
	return pdsReset($self->{pds});
}

#############################################################
#
#############################################################
sub get {
	my ($self, $name, $type) = @_;
	return if !defined($name);
	if(!defined($type)) {
		$type = PDS_PCH;
	}
	my $value; 

	if ($type == PDS_PCH) {
		$value = pdsGet_PCH($self->{pds}, $name);
		$type  = "PCH";
	}
	elsif ($type == PDS_INT) {
		$value = pdsGet_INT($self->{pds}, $name);
		$type  = "INT";
	}
	elsif ($type == PDS_F) {
		$value = pdsGet_F($self->{pds}, $name);
		$type  = "FLOAT";
	}
	elsif ($type == PDS_PDS) {
		my $rd = pdsGet_PDS($self->{pds}, $name);
		if ($rd) {
			nimLog(3,"PDS::get -  PDS,  $name");
			return Nimbus::PDS->new($rd, 1);
		}

	}
	nimLog(3, "PDS::get -  $type,  $name = $value");
	return $value;
}

sub getString {
	my ($self, $name) = @_;
	return $self->get($name, PDS_PCH);
}

sub getNumber {
	my ($self, $name) = @_;
	return $self->get($name, PDS_INT);
}

sub getFloat {
	my ($self, $name) = @_;
	return $self->get($name, PDS_F);
}

sub getPDS {
	my ($self, $name) = @_;
	return $self->get($name, PDS_PDS);
}

#############################################################
#
#############################################################
sub getTable {
	my $self  = shift;
	my $name  = shift;
	my $type  = shift || PDS_PCH;
	my $indx  = shift;

	return if !defined($name);
	if (!defined($indx)) {
		$indx =	$self->{getTableIndex};
	}

	##############################################
	# Retrieve type from pds by using name...
	my ($rc, $rd) = pdsGetTable($self->{pds}, $type, $name, $indx);
	if ($rc == 0) {
		$self->{getTableIndex}++;
		return Nimbus::PDS->new($rd,1) if $type == PDS_PDS;
		return $rd;
	}
	$self->{getTableIndex} = 0;
	return;
}

#############################################################
# HOTFIXED Version of getTable
#############################################################
sub getCompleteTable {
	my $self  = shift;
	my $pds   = shift || $self->{pds};
	my $name  = shift;
	my $type  = shift || PDS_PCH;

	my $tableIndex = 0;
	my @tableValues = ();
	while($rc_table == 0) {
		my ($rc_table, $rd) = pdsGetTable($pds, $type, $name, $tableIndex);
		last if $rc_table != PDS_ERR_NONE;
		push(@tableValues, $rd);
		$tableIndex++;
	};
	return \@tableValues;
}

#############################################################
# Put any (detectable) PDS type
#############################################################
sub put {
	my ($self, $name, $value, $type) = @_;
	return 0 if !defined($name) || !defined($value);
	if (!defined($type)) {
		my $valueType = ref($value);
		if ($valueType eq "Nimbus::PDS") {
			$type = PDS_PDS;
		}
		elsif ($valueType eq "SCALAR") {
			$type = PDS_PCH;	
		}
	}

	nimLog(3, "PDS::put - name: $name, value: $value, type: $type");
	return $self->putString($name, $value) if $type == PDS_PCH;
	return $self->putNumber($name, $value) if $type == PDS_INT;
	return $self->putFloat($name, $value) if $type == PDS_F;
	return $self->putPDS($name, $value) if $type == PDS_PDS;
	nimLog(3, "PDS::put - unknown type");
	return 0;
}

#############################################################
#
#############################################################
sub number {
	return putInteger(@_);
}

#############################################################
#
#############################################################
sub integer {
	return putInteger(@_);
}

#############################################################
# putString shorthand
#############################################################
sub string {
	return putString(@_);
}

#############################################################
# putFloat shorthand
#############################################################
sub float {
	return putFloat(@_);
}

#############################################################
# Put a String 
#############################################################
sub putString {
	my ($self, $name, $value) = @_;
	return 0 if !defined($name);
	pdsPut_PCH($self->{pds}, $name, $value || '');
	return 1;
}

#############################################################
# Put a number
#############################################################
sub putInteger {
	my ($self, $name, $value) = @_;
	return 0 if !defined($name);
	pdsPut_INT($self->{pds}, $name, $value || 0);
	return 1;
}

#############################################################
# Another way to call putInteger
#############################################################
sub putNumber {
	return putInteger(@_);
}

#############################################################
# Put a float object
#############################################################
sub putFloat {
	my ($self, $name, $value) = @_;
	return 0 if !defined($name);
	pdsPut_F($self->{pds}, $name, $value || '0.0');
	return 1;
}

#############################################################
# Put a PDS Object
#############################################################
sub putPDS {
	my ($self, $name, $value) = @_;
	return 0 if !defined($name) || !defined($value);
	pdsPut_PDS($self->{pds}, $name, ref($value) eq "Nimbus::PDS" ? $value->{pds} : $value);
	return 1;
}

#############################################################
# Put a PDS table Object
#############################################################
sub putTable {
	my ($self, $name, $value) = @_;
	my $type  = shift || PDS_PCH;
	return pdsPutTable($self->{pds}, PDS_PDS, $name, $value->{pds}) if ref($value) eq "Nimbus::PDS";
	return pdsPutTable($self->{pds}, $type, $name, $value);
}

############################################################
# Return PDS elements in hash.
############################################################
sub asHash {
	my $self = shift;
	my $hptr = shift || {};
	my $pds  = shift || $self->{pds};
	my $lev  = shift || 1;

	my ($rc, $key, $type, $size, $value);
	my $line = "-" x $lev;
	while($rc == 0) {
		($rc, $key, $type, $size, $value) = pdsGetNext($pds);
		next if $rc != PDS_ERR_NONE;
		if ($type == PDS_PDS) {
			if (!defined($hptr->{$key})) {
				nimLog(3,"PDS::asHash $line>Adding PDS: $key\n");
				$hptr->{$key} = {};
			}
			$self->asHash($hptr->{$key}, $value, $lev + 1);
			pdsDelete($value);
		}
		elsif ($type == PDS_PPCH || $type == PDS_PPI) {
			nimLog(3,"PDS::asHash $line>Adding Array: $key\n");
			$hptr->{$key} = $self->getCompleteTable($pds, PDS_PCH, $key);
		}
		elsif ($type == PDS_PPDS) {
			my @PDSValues = ();
			my $PDSArr = $self->getCompleteTable($pds, PDS_PDS, $key);
			print Dumper($PDSArr);
			$hptr->{$key} = \@PDSValues;
		}
		else {
			nimLog(3, "PDS::asHash $line>Adding key/value: $key = $value");
			$hptr->{$key} = $value;
		}
	};
	return $hptr;
}

1;

__END__

=head1 NAME

Nimbus::PDS - Object interface wrapping the PDS

=head1 SYNOPSIS

 use Nimbus::PDS

 my $pds = Nimbus::PDS->new( [$pdsData] );

          $pds->data();
          $pds->dump();
          $pds->rewind();
          $pds->reset();
          $pds->remove($name);
          $pds->string($name,$value);
          $pds->number($name,$value);
          $pds->float ($name,$value);
          $pds->put ($name,$value [,$type]);
          $pds->putTable ($name,$value [,$type]);
 $value = $pds->getTable ($name [,$type]);
 $value = $pds->get ($name [,$type]);
 $hptr  = $pds->asHash();

=head1 DESCRIPTION

The PDS object is a class wrapper around the Nimbus::API PDS functions.

=head1 CLASS METHODS

=head2 get

The get method....

=head2 put

The put method....

=head2 dump

The dump method....

=head2 putTable

The putTable method....

=head2 asHash

The asHash method will produce an associative array (hash) by traversing
the PDS. If the PDS contains other PDS's, then the hiearchy will be preserved
by nesting.

 Example:

 use Nimbus::PDS;
 my $pds = Nimbus::PDS->new();
 $pds->string("name","Donald Duck");
 $pds->number("age",60);

 my $h = $pds->asHash();
 print "name: $h->{name}, age: $h->{age}\n";

=head1 AUTHOR
 
 Nimbus Software AS.
 mailto:nimsoft@nimsoft.no
 http://www.nimsoft.no

=head1 SEE ALSO
	 
Nimbus::API, perl(1).

