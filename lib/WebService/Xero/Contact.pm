package WebService::Xero::Contact;

use 5.012;
use strict;
use warnings;
use Carp;

use Data::Dumper;
use JSON::XS;
use WebService::Xero::DateTime;
use WebService::Xero::Phone;
use WebService::Xero::Address;
use WebService::Xero::ContactPerson;
=head1 NAME

WebService::Xero::Contact - encapsulates a Xero API Contact record

=head1 VERSION

Version 0.13

=cut

our $VERSION = '0.13';

our @PARAMS = qw/ContactID ContactNumber ContactStatus AccountNumber Name FirstName LastName EmailAddress SkypeUserName 
                 BankAccountDetails TaxNumber AccountsReceivableTaxType AccountsPayableTaxType
                 UpdatedDateUTC IsCustomer IsSupplier HasAttachments HasValidationErrors
                 Addresses Phones ContactGroups ContactPersons DefaultCurrency
                /;



=head1 SYNOPSIS


Object to describe an Contact record as specified by Xero API and the associated DTD at 
L<https://github.com/XeroAPI/XeroAPI-Schemas/blob/master/src/main/resources/XeroSchemas/v2.00/Contact.xsd>.

Encapsulate Xero Contact data structure and handles some of the conversion for nested structures, dates and booleans to 
assist in manipulating. 

Also provide a few helper functions such as get_all_using_agent() which includes paging.



=head2 Example 1

    use WebService::Xero::Agent::PrivateApplication;
    use  WebService::Xero::Contact;

    my $agent            = WebService::Xero::Agent::PrivateApplication->new( ... etc 
    my $contact_response = $agent->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/297c2dc5-cc47-4afd-8ec8-74990b8761e9' ) || die( 'check the agent for error message' );

    my $contact =  WebService::Xero::Contact->new( %{$contact_response->{Contacts}[0]} );
    print $contact->as_text();

=head2 Example 2
    use WebService::Xero::Agent::PrivateApplication;
    use  WebService::Xero::Contact;
    my $agent            = WebService::Xero::Agent::PrivateApplication->new( ... etc     

    my $contact_list = WebService::Xero::Contact->get_all_using_agent( agent=> $agent ); 
    foreach my $contact ( @$contact_list )
    {
      # print $contact->as_json();
      print "$contact->{Name} $contact->{FirstName} $contact->{LastName} $contact->{EmailAddress}\n";
    }



=head2 NOTES FROM XERO DOCS

    Optional parameters for GET Contacts
      Record filter
        You can specify an individual record by appending the value to the endpoint, i.e. GET https://.../Contacts/{identifier}
        ContactID     - The Xero identifier for a contact e.g. 297c2dc5-cc47-4afd-8ec8-74990b8761e9
        ContactNumber - A custom identifier specified from another system e.g. a CRM system has a contact number of CUST100
      Modified After
      Where
      order
      page
      includeArchived

    You can upload up to 10 attachments(each up to 3mb in size) per contact, once the contact has been created in Xero.


    XSD Available at L<https://github.com/XeroAPI/XeroAPI-Schemas/blob/master/src/main/resources/XeroSchemas/v2.00/Contact.xsd>
    API Previewer available at L<https://app.xero.com/Preview/contacts>

=head1 METHODS

=head2 new()

=cut

sub new 
{
  my ( $class, %params ) = @_;

    my $self = bless 
    {
      debug => $params{debug},
      API_URL => 'https://api.xero.com/api.xro/2.0/Contacts',

    }, $class;
    foreach my $key (@PARAMS) { $self->{$key} = defined $params{$key} ? $params{$key} : '';  }

    ## morph from text to expected types
    if ( $self->{UpdatedDateUTC} ne '')
    {
      $self->{UpdatedDateUTC} = WebService::Xero::DateTime->new( "$self->{UpdatedDateUTC}" );
     # print Dumper   $self->{UpdatedDateUTC} ;
    }
    if ( ref( $self->{Phones} ) eq 'ARRAY' ) 
    {
      my $phones_list = $self->{Phones};
      $self->{Phones} = [];
      foreach my $phone ( @{$phones_list})
      {
        push @{$self->{Phones}}, WebService::Xero::Phone->new( $phone ) || return $self->_error('Failed to create Phone instance');
      }
    }
    if ( ref( $self->{Addresses} ) eq 'ARRAY' ) 
    {
      my $address_list = $self->{Addresses};
      $self->{Addresses} = [];
      foreach my $address ( @{$address_list})
      {
        push @{$self->{Addresses}}, WebService::Xero::Address->new( $address ) || return $self->_error('Failed to create Address instance');
      }
    }

    ## ContactStatus: [ ACTIVE || ARCHIVED ]

    ## TODO: if not looking to use Moose then consider creating Moose-like getters and setters.

    return $self; #->_validate_agent(); ## derived classes will validate this

}

=head2 new_using_agent()

  Input Parameters: 
     agent => an agent of type Xero::WebService::Agent::* - this is used to handle to handle the communciation with Xero Servers
     filters => { ## an optional set of parameters to be passed as part of the request to xero
       not implemented yet
     }

  Process:
    Construct a paged query string using filters if provided and use the agent to request data through the Xero API.
    Return the results as valid WebService::Xero::Contact object(s) or empty array

  Output:
    If there was an error then undef is returned and the agent will contain the description of the issue.
    Where a valid single result is returned by the Xero Agent, a single instance of WebService::Xero::Contact is returned.
    Where multiple valid results are returned by the Xero Agent, an array of instances of WebService::Xero::Contact is returned.


=cut 

sub get_all_using_agent
{
  my ( $self, %params ) = @_;
  $self = WebService::Xero::Contact->new() if ( $self eq 'WebService::Xero::Contact'); ## create an instance if called without one
  return $self->_error('agent is a required parameter') unless ( ref( $params{agent} ) =~ /^WebService::Xero::Agent/m);

  my $page = 1; my $finished = 0; my $all_contacts = [];
  do  ## 'https://api.xero.com/api.xro/2.0/Contacts'
  {
    if ( my $res = $params{agent}->do_xero_api_call( "$self->{API_URL}?page=$page" ) )
    {
      $page++;
      my $paged_contacts = $self->new_array_from_api_data( $res );
      $finished = 1 if (@$paged_contacts != 100 );
      push @$all_contacts, @$paged_contacts;
    }
    else 
    {
       return $self->_error('FAILED: agent returned an error - check the agent status for details');
    }
  } until ( $finished == 1 );
  return $all_contacts;
}

=head2 new_from_api_data()

  creates a new instance from the data provided by querying the API organisation end point 
  ( typically handled by WebService::Xero::Agent->do_xero_api_call() )

  Example Contact Queries using Xero Agent that return Data consumable by this method:
    https://api.xero.com/api.xro/2.0/Contacts

  Returns undef, a single object instance or an array of object instances depending on the data input provided.


=cut 

sub new_array_from_api_data
{
  my ( $self, $data ) = @_;
  #return WebService::Xero::Contact->new(  %{$data->{Contacts}[0]} ) if ( ref($data->{Contacts}) eq 'ARRAY' and scalar(@{$data->{Contacts}})==1 );
  # using above returns a single object if only 1 element is data .. removed to consistently return an array - even if only 1 element.
  my $contacts_list = [];
  foreach my $contact  ( @{$data->{Contacts}} )
  {
    push @$contacts_list, WebService::Xero::Contact->new( %{$contact} );
  }
  return $contacts_list;
  # return WebService::Xero::Contact->new( debug=> $data );  

}

=head2 as_text()

  useful for debugging.

=cut


sub as_text 
{
    my ( $self, $sep, $show_head  ) = @_;
    $sep = "\n" unless $sep;
    my $ret = ''; my $head = '';
    foreach my $prop ( @PARAMS )
    {
      $head .= "$prop$sep";
      $ret .= "$prop: " if ( $sep eq "\n" && $show_head);
      if ( ref($self->{$prop}) eq '') ## then assume string or scalar
      {
        $ret .= "$self->{$prop}$sep";
      } 
      elsif ( ref($self->{$prop}) eq 'WebService::Xero::DateTime' )
      {
        $ret .= $self->{$prop}->as_datetime() . "$sep";
      } 
      elsif ( ref($self->{$prop}) eq 'JSON::PP::Boolean')
      {
        $ret .= ('false','true')[$self->{$prop}] . $sep;
      }
      elsif ( ref($self->{$prop}) eq 'ARRAY') ## assume that lists are either a hash or an class
      {
        my $count = 0;
        my $item_class = 'unknown';
        foreach my $item ( @{$self->{$prop}} )
        {
          #$ret .= ref( $item );
          
          if ( $item_class eq 'unknown' && ref($item) =~ /WebService::Xero/m )
          {
            $item_class = ref($item);
          }
          elsif ( $item_class eq 'unknown' && ref($item) eq 'HASH' )
          {
            $item_class = ref($item);
          }
          elsif ( $item_class ne 'unknown' && ref($item) ne  $item_class )
          {
            $item_class = 'EXPECPECTED MIXED CONTENT';
          }
          $count++;
        }
        if ( $count == 0 )
        {
          $ret .= "EMPTY LIST of $prop$sep";

        }
        else 
        {
          if ($item_class eq 'HASH')
          {
            $item_class = "$prop as hashes" ;
          }
          elsif ( $item_class eq 'WebService::Xero::Phone')
          {
            foreach my $ph (@{$self->{$prop}} )
            {
              $ret .= $ph->as_text();
            }

          }
          else 
          {
            $ret .= "$count Records ($item_class)" . $sep;
          }
          
        }
      }
      else
      {
        $ret .= ref($self->{$prop}) . "$sep";
      }
    }
    $head =~ s/$sep$/\n/smg; ## replace trailing sep from head with newline
    $ret =~ s/$sep$//smg; ## remove trailing sep from return value

    #$ret .= join("\n", map { "$_ : $self->{$_} :: ref='" . ref($self->{$_}) . "'" if (ref($self->{$_}) eq '') } @PARAMS);# . "UpdateDateUTC" . $self->{UpdateDateUTC}->as_datetime();
    $ret = "$head$ret" if ($show_head && $sep ne "\n"); ## prepend header to return value if flag set
    return $ret;
}



=head2 as_json()

  returns the object including all properties as a JSON struct.

=cut 
sub as_json
{
  my ( $self ) = @_;
  my $json = new JSON::XS;
  $json = $json->convert_blessed ([1]);
  return  $json->encode( $self ) ; 
}



=head2 TO_JSON()

  is called by a potential parent to_json that recursively looks for an unblssed version using calls to TO_JSON.

=cut
sub TO_JSON
{
  my ( $self ) = @_; 
  return {
            ContactID      => $self->{ContactID},
            ContactNumber  => $self->{ContactNumber},
            ContactStatus  => $self->{ContactStatus},
            AccountNumber  => $self->{AccountNumber},
            Name           => $self->{Name},
            FirstName      => $self->{FirstName},
            LastName       => $self->{LastName},
            EmailAddress   => $self->{EmailAddress},
            SkypeUserName  => $self->{SkypeUserName},
            BankAccountDetails => $self->{BankAccountDetails},
            TaxNumber      => $self->{TaxNumber},
            AccountsReceivableTaxType => $self->{AccountsReceivableTaxType},
            AccountsPayableTaxType => $self->{AccountsPayableTaxType},
            UpdatedDateUTC => $self->{UpdatedDateUTC}, #->TO_JSON(),
            IsCustomer     => $self->{IsCustomer},
            IsSupplier     => $self->{IsSupplier},
            HasAttachments => $self->{HasAttachments},
            HasValidationErrors => $self->{HasValidationErrors},
            Addresses      => $self->{Addresses},
            Phones         => $self->{Phones}, #$self->Phones_as_JSON(),
            ContactGroups  => $self->{ContactGroups},
            ContactPersons => $self->{ContactPersons},
            DefaultCurrency => $self->{DefaultCurrency},
  }; 
}

sub _error
{
  my ( $self, $msg ) = @_;
  warn( $msg );
  return undef;
}

=head1 AUTHOR

Peter Scott, C<< <peter at computerpros.com.au> >>


=head1 REFERENCE

=head2 PROPERTIES

The following properties can be accessed as hash keyed values such as $contact->{ContactID}

=over 4

=item  * AccountNumber

=item  * AccountsPayableTaxType

=item  * AccountsReceivableTaxType

=item  * Addresses

=item  * BankAccountDetails

=item  * ContactGroups

=item  * ContactID

=item  * ContactNumber

=item  * ContactPersons

=item  * ContactStatus

=item  * DefaultCurrency

=item  * EmailAddress

=item  * FirstName

=item  * HasAttachments

=item  * HasValidationErrors

=item  * IsCustomer

=item  * IsSupplier

=item  * LastName

=item  * Name

=item  *  Phones

=item  *  SkypeUserName

=item  * TaxNumber

=item  * UpdatedDateUTC

=back


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

1; # End of WebService::Xero
