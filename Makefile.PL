use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Apache::AxKit::Language::XSP::Sendmail',
    'VERSION_FROM' => 'Sendmail.pm', # finds $VERSION
    'PREREQ_PM' => {AxKit => 1.2, Mail::Sendmail => '', Email::Valid => ''},
);
