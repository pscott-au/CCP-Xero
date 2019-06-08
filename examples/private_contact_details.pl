#!/usr/bin/perl

use strict;
use warnings;
use Config::Tiny;
use WebService::Xero::Agent::PrivateApplication;
use Crypt::OpenSSL::RSA;
use Data::Dumper;
use File::Slurp; ## readfile
use DateTime;
use Time::Local;
use WebService::Xero::DateTime;
use WebService::Xero::Contact;
use feature 'say';
use JSON::XS;
my $DEBUG = 1; ## if set display debug info


=pod

=head1 private_contact_details.pl

=head2 SYNOPSIS

 walks through a couple of approaches to retrieving Contact records

=head2 CONFIGURATION

 private application credentials are assumed to have been specified in the t/config/test_config.ini file

=head2 USAGE

 Ensure that configuration is set in ./t/config/test_config.ini
 Uncomment lines as appropriate or modify (1==1) <-> (1==2) to enable or disable blocks of code
 ./private_company_account_details.pl

=cut



## Start by creating a PrivateApplication Agent to access Xero API

die('Configuration is assumed to be defined in the ./t/config/test_config.ini file - copy the template file in the same directory and modify with references to your Private Application API keys and secret') unless -e '../t/config/test_config.ini';
my $config =  Config::Tiny->read( '../t/config/test_config.ini') || die('failed to load config');
my $pk_text = read_file( $config->{PRIVATE_APPLICATION}{KEYFILE} );
my $pko;
eval { $pko  = Crypt::OpenSSL::RSA->new_private_key( $pk_text ) }; # 'Generate RSA Object from private key file'

my $xero = WebService::Xero::Agent::PrivateApplication->new( 
                                                          NAME            => $config->{PRIVATE_APPLICATION}{NAME},
                                                          CONSUMER_KEY    => $config->{PRIVATE_APPLICATION}{CONSUMER_KEY}, 
                                                          CONSUMER_SECRET => $config->{PRIVATE_APPLICATION}{CONSUMER_SECRET}, 
                                                         # KEYFILE         => $config->{PRIVATE_APPLICATION}{KEYFILE},
                                                          PRIVATE_KEY     => $pk_text,
                                                          ) || die('unable to create xero private agent ');

##
##
##    SECTION 1 - RETRIEVE CONTACTS 
##
##

##### APPROACH 1 - Construct the API call URLS manually and handle the response - recommended for single contact

if ( 1==1 ) ## demonstration by performing direct API call and then converting the result into contact object(s)
{
  ## uncomment one of these to either query for a single or all Contacts using the agent do_xero_api_call method.
  #   my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/' ) || die( 'Contacts Request failed: ' . $xero->{_status} );
     my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/1b4c189f-2c88-4eb1-b052-004b9704d757' ) || die( 'Contacts Request failed: ' . $xero->{_status} );
  #   my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/' . '?where=Name.Contains("Peter")' ) || die( 'Contacts Request failed: ' . $xero->{_status} );
  #   my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/' . '?where=EmailAddress!=null' ) || die( 'Contacts Request failed: ' . $xero->{_status} );
  ## NB it appears that trying to add complex filters requires some additional magic as per 


  print qq{
      XERO RESPONSE: 
            $contact_response->{'DateTimeUTC'}
            $contact_response->{'Id'}
            $contact_response->{'Status'}
            $contact_response->{'ProviderName'}          
  } if $DEBUG;
  #print Dumper $contact_response->{'Contacts'} if $DEBUG;
  
  ## NB the response MAY not include all records .. Xero suggests you paginate reqeusts into 100 record blocks to ensure all records - this is handled by the Class using Contacts get_all_using_agent method ( Approach 2 below )
  ## $contact_response->{'Contacts'} contains JSON data describing the contacts but to use we need to handle the Xero Date formatting, booleans etc
  if ( $contact_response->{'Contacts'} > 0 ) 
  {
    print "Response returned " . scalar(@{$contact_response->{'Contacts'}} ) . " records\n";
    contacts_list_as_short_text( WebService::Xero::Contact->new_array_from_api_data( $contact_response)  ); 
    # print contacts_list_as_json( WebService::Xero::Contact->new_array_from_api_data( $contact_response) ); ## convert the response into a list of WebService::Xero:Contact instances and print as JSON
  } else {
    print "Xero did not return any Contacts\n";
  }
}



###### APPROACH 2 - Recommended for retrieving every contact record

if ( 1==2 ) ## demonstration by calling the class method get_all_using_agent to construct the array ref of Contact instances
{
  my $contact_list = WebService::Xero::Contact->get_all_using_agent( agent=> $xero ); 
  contacts_list_as_short_text( $contact_list );

  ## print contacts_list_as_json( $contact_list ); 
  exit;
}




##
##
##    SECTION 2 - CREATE CONTACT
##
##
## my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/' . '?where=EmailAddress!=null' ) || die( 'Contacts Request failed: ' . $xero->{_status} );
## do_xero_api_call( $self, $uri, $method, $xml ) )
if ( 1==2)
{
 my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts','POST', 
q{
<Contact>
  <ContactNumber>FJS</ContactNumber>
  <Name>ABC Limited</Name>
  <FirstName>John</FirstName>
  <LastName>Smith</LastName>
  <EmailAddress>john.smith@gmail.com</EmailAddress>
  <Addresses>
    <Address>
      <AddressType>POBOX</AddressType>
      <AddressLine1>P O Box 123</AddressLine1>
      <City>Wellington</City>
      <PostalCode>6011</PostalCode>
    </Address>
  </Addresses>
  <BankAccountDetails>01-0123-0123456-00</BankAccountDetails>
  <TaxNumber>12-345-678</TaxNumber>
  <AccountsReceivableTaxType>OUTPUT</AccountsReceivableTaxType>
  <AccountsPayableTaxType>INPUT</AccountsPayableTaxType>
  <DefaultCurrency>NZD</DefaultCurrency>
</Contact>
} ) || die( 'Contacts Request failed: ' . $xero->{_status} );
# print Dumper $contact_response;
print "Agent Status = $xero->{status} \n\nResponse Status = $contact_response->{Status}\n";
}



##
##
##    SECTION 3 - UPDATE CONTACT
##
##
=pod

=head2 WORK IN PROGRESS

Currently you will need to manually construct the XML payload to update a contact

 my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/1b4c189f-2c88-4eb1-b052-004b9704d757','POST', 
q{
<Contact>
  <ContactID>1b4c189f-2c88-4eb1-b052-004b9704d757</ContactID>
  <ContactNumber>FJS</ContactNumber>
  <Name>ABC Limited</Name>
  <FirstName>John</FirstName>
  <LastName>Smith</LastName>
  <EmailAddress>john.smith@gmail.com</EmailAddress>
  <Addresses>
    <Address>
      <AddressType>POBOX</AddressType>
      <AddressLine1>P O Box 123</AddressLine1>
      <City>Wellington</City>
      <PostalCode>6011</PostalCode>
    </Address>
  </Addresses>
  <BankAccountDetails>01-0123-0123456-00</BankAccountDetails>
  <TaxNumber>12-345-678</TaxNumber>
  <AccountsReceivableTaxType>OUTPUT</AccountsReceivableTaxType>
  <AccountsPayableTaxType>INPUT</AccountsPayableTaxType>
  <DefaultCurrency>NZD</DefaultCurrency>
</Contact>
} ) || die( 'Contacts Request failed: ' . $xero->{_status} );
=cut 
my $contact_response = $xero->do_xero_api_call( 'https://api.xero.com/api.xro/2.0/Contacts/1b4c189f-2c88-4eb1-b052-004b9704d757','POST', 
                                               q{
<Contact>
  <ContactID>1b4c189f-2c88-4eb1-b052-004b9704d757</ContactID>
  <EmailAddress>jane@felicityjane.com.au</EmailAddress>
</Contact>                                              
                                               } );
# print Dumper $contact_response;
print "Agent Status = $xero->{status} \n\nResponse Status = $contact_response->{Status}\n";




######### HELPER SUBS
sub contacts_list_as_short_text
{
  my ($contact_list) = @_;
  foreach my $contact ( @$contact_list )
  {
    # print $contact->as_json(); ## can use method to dump a single record as JSON
    print "$contact->{Name}::$contact->{FirstName} $contact->{LastName}::'$contact->{EmailAddress}'\n";
  }
}

sub contacts_list_as_json
{
  my ( $contact_list ) = @_;
  ## CURRENTLY TO DUMP LIST AS JSON NEED TO DO A LITTLE DANCE
  ##  thinking about creating a container class to wrap this and an iterator ..
  my $json = new JSON::XS;
  $json = $json->convert_blessed ([1]);
  return  $json->encode( $contact_list ) ; #();
  #print to_json(@$contact_list );
}


exit;

=pod 

=head2 NOTES

## The Datestring returned by Xero needs to be converted to a DateTime to simplify manipulation (done in DateTime.pm )

my $utc_str = 0;
if ( $contact_response->{'DateTimeUTC'} =~ /Date\((\d+)\)/smg )
{
    $utc_str = $1;
}
print "utc as string = $utc_str\n";
my $utc = DateTime->from_epoch( epoch => $utc_str/1000 ); ## Xero JSON responses are in milliseconds so divide by 1000 for seconds
say $utc;

my $xero_dt = WebService::Xero::DateTime->new( $contact_response->{'DateTimeUTC'} );
say $xero_dt->as_datetime();

Returning an arrayref of objects like this is pretty ugly .. thinking about approaches to abstracting a container class that generalises well.

TODO: explore the use of filters in constructing the API query string. 

NB .. we're not 'yet'? using Moose for Contacts so there are no accessors - this is why we access the data using the hash keys such as 
      $contact->{Name} instead of $contact->Name
      I am not very familiar with Moose so although I expect it would allow for a far more elegant solution my progress with it is slow.

would be nice to show an example of the JSON in a web page .. perhaps something like http://plnkr.co/edit/4AERPpfUDIvy6W1pwdCd?p=preview



=cut



