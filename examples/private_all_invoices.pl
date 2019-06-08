#!/usr/bin/env perl

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
use WebService::Xero::Invoice;
use feature 'say';
use JSON::XS;
my $DEBUG = 1; ## if set display debug info


=pod

=head1 private_all_invoices.pl

=head2 SYNOPSIS

 

=head2 CONFIGURATION

 private application credentials are assumed to have been specified in the t/config/test_config.ini file

=head2 USAGE

 Ensure that configuration is set in ./t/config/test_config.ini
 Uncomment lines as appropriate or modify (1==1) <-> (1==2) to enable or disable blocks of code


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
##    SECTION 1 - RETRIEVE INVOICES 
##
##

##### APPROACH 1 - Construct the API call URLS manually and handle the response - recommended for single contact

if ( 1==0 ) ## demonstration by performing direct API call and then converting the result into contact object(s)
{
    ## NB -- THIS ENTIRE BLOCK REMAINS UNCHANGED FROM COPY/PASTE FROM CONTACTS !! 

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
    my $contacts = WebService::Xero::Contact->new_array_from_api_data( $contact_response);
    contacts_list_as_short_text( $contacts  ); 
    if ( @$contacts == 1 )
    {
      print "\n\n" . $contacts->[0]->as_json() . "\n";;
    }
    # print contacts_list_as_json( WebService::Xero::Contact->new_array_from_api_data( $contact_response) ); ## convert the response into a list of WebService::Xero:Contact instances and print as JSON
  } else {
    print "Xero did not return any Contacts\n";
  }
}



###### APPROACH 2 - Recommended for retrieving every contact record

if ( 1==1 ) ## demonstration by calling the class method get_all_using_agent to construct the array ref of Contact instances
{
  my $contact_list = WebService::Xero::Invoice->get_all_using_agent( agent=> $xero ); 
  invoices_list_as_short_text( $contact_list );

  ## print contacts_list_as_json( $contact_list ); 
  exit;
}




##
##
##    SECTION 2 - CREATE INVOICE
##
##
if ( 1==2)
{
  ## TODO:  CREATE INVOICE
}



##
##
##    SECTION 3 - UPDATE INVOICE
##
##
=pod

=head2 WORK IN PROGRESS

=cut
# print Dumper $contact_response;
#print "Agent Status = $xero->{status} \n\nResponse Status = $contact_response->{Status}\n";




######### HELPER SUBS
sub invoices_list_as_short_text
{
  my ($invoices_list) = @_;
  foreach my $invoice ( @$invoices_list )
  {
     #print $invoice->as_json(); ## can use method to dump a single record as JSON
     print Dumper $invoice;
  }
  print "Total; invoices = " . scalar(@$invoices_list) . "\n";
}

sub invoices_list_as_json
{
  my ( $invoices_list ) = @_;
  ## CURRENTLY TO DUMP LIST AS JSON NEED TO DO A LITTLE DANCE
  ##  thinking about creating a container class to wrap this and an iterator ..
  my $json = new JSON::XS;
  $json = $json->convert_blessed ([1]);
  return  $json->encode( $invoices_list ) ; #();
  #print to_json(@$contact_list );
}


exit;

=pod 

=head2 NOTES



=cut



