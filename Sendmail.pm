package Apache::AxKit::Language::XSP::Sendmail;
use strict;
use Apache::AxKit::Language::XSP qw(start_expr end_expr expr);
use Mail::Sendmail;
use Email::Valid;

use vars qw/@ISA $NS $VERSION $ForwardXSPExpr/;

@ISA = ('Apache::AxKit::Language::XSP');
$NS = 'http://axkit.org/XSP/sendmail/v1';

$VERSION = 0.50;

## Taglib subs

# send mail
sub send_mail {
    my ($document, $parent, $mailer_args) = @_;
    my $address_errors;

    { no strict 'refs';
        foreach my $addr_type ('To', 'Cc', 'Bcc') {
            if ($mailer_args->{$addr_type}) {
                foreach my $addr (@{$mailer_args->{$addr_type}}) {
                    next if Email::Valid->address($addr);
                    $address_errors .=  "Address $addr in '$addr_type' element failed $Email::Valid::Details check. ";
                }
                $mailer_args->{$addr_type}  = join (', ', @{$mailer_args->{$addr_type}});
            }
        }
    }

    # we want a bad "from" header to be caught as a user error so we'll trap it here.
    $mailer_args->{From} ||= $Mail::Sendmail::mailcfg{from};

    unless ( Email::Valid->address($mailer_args->{From}) ) { 
        $address_errors .= "Address '$mailer_args->{From}' in 'From' element failed $Email::Valid::Details check. ";
    }

    if ($address_errors) {
        my $error_element =  XML::XPath::Node::Element->new('error');
        $error_element->appendAttribute( XML::XPath::Node::Attribute->new('type' , 'user') );
        $error_element->appendChild( XML::XPath::Node::Text->new("Invalid Email Address(es): $address_errors") );
        $parent->appendChild( $error_element );
        return 0;
    }

    # all addresses okay? if so, send.
    
    eval {
        sendmail( %{$mailer_args} ) || die $Mail::Sendmail::error . "\n";
    };

    if ($@) {
        my $error_text = $@;
        my $error_element =  XML::XPath::Node::Element->new('error');
        $error_element->appendAttribute( XML::XPath::Node::Attribute->new('type' , 'server') );
        $error_element->appendChild( XML::XPath::Node::Text->new("Mail failed: $error_text") );
        $parent->appendChild( $error_element );
    }
}

## Parser subs
        
sub parse_start {
    my ($e, $tag, %attribs) = @_; 
    #warn "Checking: $tag\n";

    if ($tag eq 'send-mail') {
        return qq| {# start mail code\n | .
                q| my (%mail_args, @to_addrs, @cc_addrs, @bcc_addrs);| . qq|\n|;
    }
    elsif ($tag eq 'to') {
        return q| push (@to_addrs, ''|;
    }
    elsif ($tag eq 'cc') {
        return q| push (@cc_addrs, ''|;
    }
    elsif ($tag eq 'bcc') {
        return q| push (@bcc_addrs, ''|;
    }
}

sub parse_char {
    my ($e, $text) = @_;
    my $element_name = $e->current_element();


    unless ($element_name eq 'body') {
        $text =~ s/^\s*//;
        $text =~ s/\s*$//;
    }

    return '' unless $text;

    if ($element_name eq 'from') {
        return q| $mail_args{From} = '| . $text . qq|';\n |;
    }
    elsif ($element_name eq 'subject') {
        return qq| \$mail_args{'subject'} = "$text";\n |;
    }
    elsif ($element_name eq 'smtphost') {
        return qq| \$mail_args{'smtp'} = "$text";\n |;
    }
    elsif ($element_name eq 'body') {
        return qq| \$mail_args{'message'} .= "$text";\n |;
    }
    elsif ($element_name =~ /to|bcc|cc/) {
        return qq| . '$text' |;
    }

    return '';
}


sub parse_end {
    my ($e, $tag) = @_;

    
    if ($tag eq 'send-mail') {
        return q| $mail_args{To}  = \@to_addrs; | . qq|\n| . 
               q| $mail_args{Cc}  = \@cc_addrs; | . qq|\n| .
               q| $mail_args{Bcc} = \@bcc_addrs;| . qq|\n| .
               q| Apache::AxKit::Language::XSP::Sendmail::send_mail( | .
               q| $document, $parent, \%mail_args | .
              qq| );} #end mail code\n\n\n\n |;
    }
    elsif ($tag =~ /to|bcc|cc/) {
        return ");\n";
    }
    return ";";
}

sub parse_comment {
    # compat only
}

sub parse_final {
   # compat only
}

1;
                
__END__

=head1 NAME

Apache::AxKit::Language::XSP::Sendmail - Simple SMTP mailer tag library for AxKit eXtesible Server Pages.

=head1 SYNOPSIS

Add the sendmail: namespace to your XSP C<<xsp:page>> tag:

    <?xml-stylesheet href="." type="application/x-xsp"?>>
    <xsp:page
         language="Perl"
         xmlns:xsp="http://www.apache.org/1999/XSP/Core"
         xmlns:sendmail="http://www.axkit.org/ns/sendmail"
    >

And add this taglib to AxKit (via httpd.conf or .htaccess):

    AxAddXSPTaglib Apache::AxKit::Language::XSP::Sendmail

=head1 DESCRIPTION

The XSP sendmail: taglib adds a simple SMTP mailer to XSP via Milivoj Ivkovic's platform-neutral Mail::Sendmail module. In
addition, all email addresses are validated before sending using Maurice Aubrey's Email::Valid package.

=head2 Tag Reference

=over 4

=item C<<sendmail:send-mail>>

This is the required 'wrapper' element for the sendmail taglib branch.

=item C<<sendmail:smpthost>>

The this element sets the outgoing SMTP server for the current message. If ommitted, the default set in Mail::Sendmail's
%mailcfg hash will be used instead. 

=item C<<sendmail:from>>

Defines the 'From' field in the outgoing message. If ommited, this field defaults to value set in Mail::Sendmail's %mailcfg
hash. Run C<perldoc Mall:Sendmail> for more detail.

=item C<<sendmail:to>>

Defines a 'To' field in the outgoing message. Multiple instances are allowed.

=item C<<sendmail:cc>>

Defines a 'Cc' field in the outgoing message. Multiple instances are allowed.

=item C<<sendmail:bcc>>

Defines a 'Bcc' field in the outgoing message. Multiple instances are allowed.

=item C<<sendmail:body>>

Defines the body of the outgoing message.

=back

=head1 EXAMPLE

my $mail_message = 'I'm a victim of circumstance!';

C<<sendmail:send-mail>>
  C<<sendmail:from>>curly@localhostC<</sendmail:from>>
  C<<sendmail:to>>moe@spreadout.orgC<</sendmail:to>>
  C<<sendmail:cc>>larry@porcupine.comC<</sendmail:cc>>
  C<<sendmail:bcc>>shemp@alsoran.netC<</sendmail:cc>>
  C<<sendmail:body>>C<<xsp:expr>>$mail_messageC<</xsp:expr>>C<</sendmail:body>>
C<</sendmail:send-mail>>

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2001 Kip Hampton. All rights reserved. This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

AxKit, Mail::Sendmail, Email::Valid

=cut
