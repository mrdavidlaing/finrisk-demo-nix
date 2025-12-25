use 5.010;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'TransferX::AuditService',
    VERSION_FROM  => 'audit-service.pl',
    PREREQ_PM     => {
        'JSON' => 0,
        'HTTP::Server::Simple' => 0,
        'HTTP::Server::Simple::CGI' => 0,
        'HTTP::Status' => 0,
    },
    EXE_FILES     => ['audit-service.pl'],
    ABSTRACT      => 'TransferX Audit Service',
    AUTHOR        => 'TransferX Team',
);


