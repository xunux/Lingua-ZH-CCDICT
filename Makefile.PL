use ExtUtils::MakeMaker;

WriteMakefile( NAME         => 'Lingua::ZH::CCDICT',
               VERSION_FROM => 'lib/Lingua/ZH/CCDICT.pm',
               AUTHOR       => 'David Rolsky (autarch@urth.org)',
               ABSTRACT     => 'An interface to the CCDICT Chinese dictionary',
               PREREQ_PM    =>
               { BerkeleyDB => 0.19,
                 Storable   => 0,
                 'Params::Validate' => 0.24,
                 'Test::More'       => 0.46,
               },
             );

package MY;

sub libscan
{
    my $self = shift;
    my $file = shift;

    return $file =~ /svn/ ? 0 : $self->SUPER::libscan($file);
}
