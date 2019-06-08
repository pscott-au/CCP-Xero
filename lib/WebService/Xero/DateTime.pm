package WebService::Xero::DateTime;
use DateTime;

=pod 

=head1 NAME

WebService::Xero::DateTime - Helper to manage Xero formatted JSON DateTime data

=head1 VERSION

Version 0.13

=head1 SYNOPSIS

A helper class for date handling.

=head2 NOTES

    

=head1 METHODS

=head2 new()

  INPUT: single parameter string in Xero JSON format

=cut


our $VERSION = '0.13';

use Exporter;
@EXPORT = qw/xero_date_text_as_date_object/;
#    if ( $dates->{$k} =~ /\/Date\(([\d|\+|\-]+)\)\//mg )
#    {
#        my $ms_full = $1;
#        #print "-- $ms_full\n";
#        if ($ms_full =~ /^(\d+)([+|-]\d{4})$/mg)
#        {
#            my $dt = DateTime->from_epoch( epoch => $1/1000, time_zone=>$2 );
#            print $dt . "\n";
#        }
#    }

sub new 
{
    my ( $class, $xero_date_string ) = @_;
    my $self = {
      _utc => 0,
    };
    if ( $xero_date_string =~  /\/{0,1}Date\(([\d]+)[\+|\-]{0,1}(\d{4})\)\/{0,1}$/mg )
    {
        my $utc_str = $1;
        $self->{_utc} = DateTime->from_epoch( epoch => $utc_str/1000, time_zone=>$2 ) || die("critical failure creating date from $xero_date_string");
        

        return bless $self, $class;
    } 
    else 
    {
        die( "Unknown ISSUE !!!");
        return bless $self, $class;
    }
    return undef; ## default if conditions aren't right
    
}


=head2 xero_date_text_as_date_object()

  returns DateTime object

=cut

sub xero_date_text_as_date_object
{
    my ( $self, $xero_date_string ) = @_;

    my $dt = undef;
    if ( $xero_date_string =~  /\/{0,1}Date\(([\d]+)[\+|\-]{0,1}(\d{4})\)\/{0,1}$/mg )
    {
        my $utc_str = $1; $tz = $2;
        $dt = DateTime->from_epoch( epoch => $utc_str/1000, time_zone=>$tz ) || return undef;
    }    
    return $dt;
}



=head2 as_datetime()

  returns DateTime object

=cut

sub as_datetime
{
    my ( $self ) = @_;
    return $self->{_utc};
}

sub as_text
{
    my ( $self ) = @_;
    return $self->{_utc} . "";
}

=head2 TO_JSON()

  allows for recursive conversion to_json from a parent container.

=cut
sub TO_JSON
{
  my ( $self ) = @_;
  return $self->as_text();
}

=head1 AUTHOR

Peter Scott, C<< <peter at computerpros.com.au> >>


=head1 REFERENCE


=head1 BUGS

Please report any bugs or feature requests to C<bug-webservice-xero at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WebService-Xero>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 TODO


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::Xero::Contact


You can also look for information at:

=over 4

=item * Xero Developer API Docs

L<https://developer.xero.com/documentation/api/contacts/>


=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016-2019 Peter Scott.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of WebService::Xero::DateTime

