#!/usr/bin/perl -w
## Installation de modules perl -MCPAN -e 'shell'
use strict;
use LWP::Debug qw(+);
use WWW::Mechanize;
use LWP::UserAgent;
use Data::Dumper;
use HTTP::Cookies;
use Try::Tiny;
use Unicode::Normalize; # for NFD()
use Encode; 		# for decode_utf8()
use utf8;
use Fcntl qw(:flock);  # pour le verrouillage de fichier

# utilisation d'un verrou pour éviter que le script ne se lance plusieurs fois en même temps (en particulier avec incron)
my $verrou = '/var/lock/lyzmap_sync.exclusivelock';

open(LOCK, ">>", "$verrou") || die "ERROR openning $verrou\n";
# Wait for lock
flock LOCK, LOCK_EX;


my $log = "/var/log/lizmap_sync/lizmap_sync.log";
open(LOG,">>$log") or die "cannot open $log";
binmode(LOG, ":encoding(utf8)");		# L'écriture en sortie vers LOG sera en utf8. Si rien, erreur sur les caractères spéciaux des chaines
print LOG "\n \n";
my $datestring = localtime();
print LOG $datestring;
print LOG "\n";

## ---- Vérification des paramètres d'entrée -----

if (@ARGV == 0) {
	print LOG "Aucun argument n'est renseigné !!";
	exit;
} elsif (@ARGV == 1) {
        print LOG "Un seul argument en entrée : ${ARGV[0]}\n";
} elsif (@ARGV > 2) {
	print LOG "Il y a plus de deux arguments en entrée !! \n 1er argument : ${ARGV[0]}  -  2ème argument : ${ARGV[1]} - et un 3ème ${ARGV[2]} au moins... !!";
	exit;
} else {
        # 2 arguments
        my $arg1 = decode_utf8($ARGV[1]);     # Le decode_utf8 permet l'affichage des caractères spéciaux des chaines issues d'arguments
	print LOG "Arguments réceptionnés : ${ARGV[0]}  -  ${arg1} \n";
}	

### ----- Regarde s'il s'agit d'un ajout ou d'une suppression -----
### ----- Change le fichier de log selon le type d'action -----

#my $event_type = $ARGV[0];
#if ($event_type =~ m/IN_CREATE/){
#	$log = "/var/log/lizmap_sync/lizmap_sync_add.log";
#} elseif ($event_type =~ m/IN_DELETE/){
#	$log = "/var/log/lizmap_sync/lizmap_sync_remove.log";
#} else {
#	exit;
#}
##open(LOG,">>$log") or die "cannot open $log";
#print LOG "\n";
#my $datestring = localtime();
#print LOG $datestring;
#print LOG "\n";

## ----- Met en forme le nom du dossier reçu pour préparer l'identifiant (accents, caractères spéciaux dont _) -----

my $repository0 = decode_utf8($ARGV[1]);	# http://ahinea.com/en/tech/perl-unicode-struggle.html solution 1
my $repository = NFD($repository0);		# Utiliser forcément une variable de sortie différente que celle d'entrée
$repository =~ s/\p{Mn}//g;
$repository =~ s/[^\w]+//g;			# A mettre après la suppression des accents car supprime les lettres qui en comportent
$repository =~ s/(_|\.)+//g;
$repository =~ s/(.+)/\L$1/gi;     		# Met tout en minuscules
print LOG "Identifiant : ${repository} \n";

## ----- Création de l'objet Mechanize ------

my $mech = WWW::Mechanize->new();

## ----- Identification sur le site internet si besoin -----

## test si déjà logué sinon essaye de s'identifier

if (! is_authenticated()) {
	authentify();
} 

sub is_authenticated {
    my $is_authenticated = 0;
	try {
		my $response = $mech->get( "https://lizmap-mshe.univ-fcomte.fr/admin.php/master_admin/" );
		if ($response->is_success) {
			if ( $response->decoded_content =~ /user_login/ ) { ## si le contenu de la page retournée contient une certaine chaine, considére qu'on est authentifié
			$is_authenticated = 1;
			}
		}
	} catch {

	};
	return $is_authenticated;
}

sub authentify {
	my $url = "https://lizmap-mshe.univ-fcomte.fr/lm/admin.php/admin/config/";
	my $passFilePath = "/home/lizmap/.lizmappass"; ## le fichier doit contenir : "lelogin:lepassword"
	my %credentials;
	try {
			%credentials = get_credentials($passFilePath);
			defined($credentials{login}) or die $!;
			defined($credentials{password}) or die $!;

	} catch {
			print LOG "Impossible de lire le login ou mot de passe pour lizmap\n";
			print LOG "error : $_ ";
			exit;
	};
	try {
		$mech->get( $url );                       # Accès à l'url
		$mech->form_id("loginForm");              # Accès au formulaire
			$mech->field("login",$credentials{login});            # Accès au champ
		$mech->field("password",$credentials{password});
		$mech->field("rememberMe","1");

		$mech->click;                             # Envoi du formulaire en cliquant sur le premier bouton
	} catch {
		print LOG "Impossible de s'identifier sur Lizmap\n";
		print LOG "error : $_ ";
			exit;
	};
}

sub get_credentials {
  my ($file) = @_;
  open my $fh, "<", $file or die $!;

  my $line = <$fh>;
  chomp($line);
  my ($login, $password) = split /:/, $line;

  return (login => $login, password => $password);
}

## ----- Suite des actions sur le site internet selon l'action -----
my $event_type = $ARGV[0];
if ($event_type =~ m/IN_CREATE/){

	## ----- Publication du répertoire -----
	
	my $url2 = "https://lizmap-mshe.univ-fcomte.fr/lm/admin.php/admin/config/createSection";
	try {
		$mech->get( $url2 );
	} catch {
		print LOG "Impossible de se connecter à {$url2} !!! Le répertoire n'a pas été publié !!! \n";
		print LOG "error : $_ ";
                exit;
        };

	my $label = $ARGV[1];	
	my $label_log = decode_utf8($label);
	print LOG "Label : ${label_log} \n";
	my $path = "/home/lizmap/owncloudsync/${label}/";
	my $path_log = decode_utf8($path);
	if (-d $path) {
	        print LOG "Répertoire trouvé : ${path_log}";
        	print LOG "\n";
	} else {
        	print LOG "Le répertoire ${path_log} n'existe pas !!";
        	exit;
	}
        											# Attention !! Si caractère spéciaux mal envoyés, l'envoi échoue !!
	try {											# L'envoi des données avec accents en Latin-1 permet d'éviter les erreurs (sauf €, oe et Ÿ)
		$mech->form_id("jforms_admin_config_section")->accept_charset('iso-8859-1'); 	# Le formulaire ne traite par défaut que l'utf-8, il faut préciser qu'on envoie du Latin-1
		$mech->field("repository",$repository);		
		$mech->field("label",encode('iso-8859-1',$label));                              # Il faut donc encoder les données au moment de les envoyer
		$mech->field("path",encode('iso-8859-1',$path));
		$mech->field("allowUserDefinedThemes","1");
		$mech->click;
	} catch {
		print LOG "Impossible de remplir les champs !!! \n";
		print LOG "error : $_ ";
		exit;
	};

	# ----- Attribution des droits -----

	my $url3 = "https://lizmap-mshe.univ-fcomte.fr/lm/admin.php/admin/config/modifySection?repository=${repository}";

	try{
        	$mech->get( $url3 );
		$mech->form_id("jforms_admin_config_section")->accept_charset('iso-8859-1');
		#$mech->form_id("jforms_admin_config_section");
	        $mech->field("lizmap.repositories.view[0]","__anonymous");
        	$mech->field("lizmap.repositories.view[1]","admins");
        	$mech->field("lizmap.repositories.view[2]","lizadmins");
        	$mech->field("lizmap.repositories.view[3]","intranet");

        	$mech->field("lizmap.tools.displayGetCapabilitiesLink[0]","__anonymous");
        	$mech->field("lizmap.tools.displayGetCapabilitiesLink[1]","admins");
        	$mech->field("lizmap.tools.displayGetCapabilitiesLink[2]","lizadmins");
        	$mech->field("lizmap.tools.displayGetCapabilitiesLink[3]","intranet");

        	$mech->field("lizmap.tools.edition.use[0]","__anonymous");
        	$mech->field("lizmap.tools.edition.use[1]","admins");
        	$mech->field("lizmap.tools.edition.use[2]","lizadmins");
        	$mech->field("lizmap.tools.edition.use[3]","intranet");

        	$mech->field("lizmap.tools.layer.export[0]","__anonymous");
        	$mech->field("lizmap.tools.layer.export[1]","admins");
        	$mech->field("lizmap.tools.layer.export[2]","lizadmins");
        	$mech->field("lizmap.tools.layer.export[3]","intranet");

        	$mech->field("lizmap.tools.loginFilteredLayers.override[0]","__anonymous");
        	$mech->field("lizmap.tools.loginFilteredLayers.override[1]","admins");
        	$mech->field("lizmap.tools.loginFilteredLayers.override[2]","lizadmins");
        	$mech->field("lizmap.tools.loginFilteredLayers.override[3]","intranet");

        	$mech->click;

        	print LOG "Publication de ${repository} OK."

	} catch {
        	print LOG "Impossible de se connecter à {$url3} !!! Le répertoire n'a pas été publié !!! \n";
        	print LOG "error : $_ ";
        	exit;
	};

} elsif ($event_type =~ m/IN_DELETE/){

	## ----- Vérification de l'existence du répertoire publié -----

	my $url2 = "https://lizmap-mshe.univ-fcomte.fr/lm/admin.php/admin/config/modifySection/?repository=${repository}";
	try{
	        $mech->get( $url2 );
	} catch {
	        print LOG "Impossible de se connecter à {$url2} !!! Le projet à supprimer n'est pas publié !!!\n";
	        print LOG "error : $_ ";
	        exit;
	};

	## ----- Suppression du répertoire -----

	my $url3 = "https://lizmap-mshe.univ-fcomte.fr/lm/admin.php/admin/config/removeSection?repository=${repository}";
	try{
	        $mech->get( $url3 );
	} catch {
	        print LOG "Impossible de se connecter à {$url3} !!! Le projet n'a pas été supprimé !!! \n";
	        print LOG "error : $_ ";
	        exit;
	};
	print LOG "Suppression de ${repository} : OK. ";

} else {
	print LOG "Evenement incorrect !!!! \n Evenement : {$event_type}";
}

close LOG ;

close LOCK;

