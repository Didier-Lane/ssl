CERTS_DIR 			?= ~/.ssl
CERTS_PATH			:= $(subst ~,$(HOME),$(CERTS_DIR))
CURVE				?= secp384r1
DEFAULT_BITS 		?= $(or $(BITS),4096)
DEFAULT_MD 			?= $(or $(MD),SHA384)
REQ_DAYS 			?= $(or $(DAYS),3650)
COUNTRY 			?= $(or $(CT),FR)
STATE 				?= $(or $(ST),Paris)
LOCALITY 			?= $(or $(LO),Paris)
ORGANIZATION 		?= $(or $(OG),Local)
ORGANIZATION_UNIT 	?= $(or $(OU),IT)
# cert
COMMON_NAME			?= $(or $(CN),$(NAME))
WORKDIR				:= $(CERTS_PATH)/$(COMMON_NAME)
SUBJECT_ALT_NAMES	?= $(or $(SAN),$(ALT_NAMES))
BASE_FILENAME		:= $(WORKDIR)/$(COMMON_NAME)
CONFIG_FILE			:= $(BASE_FILENAME).cnf
PRIVATE_KEY			:= $(BASE_FILENAME).key
SIGNING_REQUEST		:= $(BASE_FILENAME).csr
CERTIFICATE			:= $(BASE_FILENAME).crt
FULLCHAIN			:= $(BASE_FILENAME).fullchain.pem
# ca
CA_COMMON_NAME		?= $(or $(CA),$(AUTHORITY),$(COMMON_NAME))
CA_WORKDIR			:= $(CERTS_PATH)/$(CA_COMMON_NAME)
CA_BASE_FILENAME	:= $(CA_WORKDIR)/$(CA_COMMON_NAME)
CA_CONFIG_FILE		:= $(CA_BASE_FILENAME).CA.cnf
CA_PRIVATE_KEY		:= $(CA_BASE_FILENAME).CA.key
CA_SIGNING_REQUEST	:= $(CA_BASE_FILENAME).CA.csr
CA_CERTIFICATE		:= $(CA_BASE_FILENAME).CA.crt
CA_SERIAL			:= $(CA_BASE_FILENAME).CA.srl

.PHONY: cn
cn:
	if [ -z "$(COMMON_NAME)" ]; then
		echo "${bold}Error : you must supply a ${yellow}COMMON_NAME${reset}${bold} in order to generate a certificate${reset}"
		exit 1
	fi

.PHONY: ca
ca: cn ## 📜 Generates A Self-Signed Certification Authority Certificate
	echo "${bold}${underline}Certification Authority${reset}"
	echo "${bold}Common Name: 			${cyan}$(CA_COMMON_NAME)${reset}"
	echo "${bold}Working Directory: 		${cyan}$(CA_WORKDIR)${reset}"
	echo "${bold}Configuration File:		${cyan}$(CA_CONFIG_FILE)${reset}"
	echo "${bold}Private Key File:		${cyan}$(CA_PRIVATE_KEY)${reset}"
	echo "${bold}Certificate Signing Request:	${cyan}$(CA_SIGNING_REQUEST)${reset}"
	echo "${bold}Certificate:			${cyan}$(CA_CERTIFICATE)${reset}"
	echo "${bold}Serial:				${cyan}$(CA_SERIAL)${reset}"

	[[ ! -z "$(or $(DRY_RUN),$(DRY))" ]] && exit 0

	if [ ! -d "$(CA_WORKDIR)" ]; then
		$(call message,📂,Creating Directory $(hl)$(CA_WORKDIR)$(rs))
		mkdir -p "$(CA_WORKDIR)"
	fi

	if [ ! -f "$(CA_PRIVATE_KEY)" ]; then
		$(call message,📜,Creating Certification Authority Private Key $(hl)$(CA_PRIVATE_KEY)$(rs))
		openssl ecparam -genkey -name "$(CURVE)" -out "$(CA_PRIVATE_KEY)"
	fi

	if [ ! -f "$(CA_CONFIG_FILE)" ]; then
		$(call message,📄,Creating Certification Authority Configuration File $(hl)$(CA_CONFIG_FILE)$(rs))
		cat <<-EOF > "$(CA_CONFIG_FILE)"
		[ req ]
		default_bits       = $(DEFAULT_BITS)
		prompt             = no
		default_md         = $(DEFAULT_MD)
		req_extensions     = v3_req
		distinguished_name = dn
		[ dn ]
		countryName  = $(COUNTRY)
		stateOrProvinceName = $(STATE)
		localityName  = $(LOCALITY)
		organizationName  = $(ORGANIZATION)
		organizationalUnitName = $(ORGANIZATION_UNIT)
		commonName = $(CA_COMMON_NAME)
		[ v3_req ]
		basicConstraints = critical,CA:TRUE
		keyUsage = critical, digitalSignature, cRLSign, keyCertSign
		subjectKeyIdentifier = hash
		EOF
	fi

	if [ ! -f "$(CA_SIGNING_REQUEST)" ]; then
		$(call message,📜,Creating Certification Authority Signing Request $(hl)$(CA_SIGNING_REQUEST)$(rs))
		openssl req -new "-$(DEFAULT_MD)" -nodes -out "$(CA_SIGNING_REQUEST)" -key "$(CA_PRIVATE_KEY)" -config "$(CA_CONFIG_FILE)"
	fi

	if [ ! -f "$(CA_CERTIFICATE)" ]; then
		$(call message,📜,Creating Certification Authority Certificate $(hl)$(CA_CERTIFICATE)$(rs))
		openssl x509 -req "-$(DEFAULT_MD)" -days "$(REQ_DAYS)" -in "$(CA_SIGNING_REQUEST)" -signkey "$(CA_PRIVATE_KEY)" \
			-extfile "$(CA_CONFIG_FILE)" -out "$(CA_CERTIFICATE)"
	fi

	if [ ! -f "$(CA_SERIAL)" ]; then
		$(call message,📜,Creating Certification Authority Serial $(hl)$(CA_SERIAL)$(rs))
		echo "01" > "$(CA_SERIAL)"
	fi

.PHONY: cert
cert: cn ca ## 📜 Generates A Self-Signed Certificate
	echo "${bold}${underline}Certificate${reset}"
	echo "${bold}Common Name: 			${cyan}$(COMMON_NAME)${reset}"
	echo "${bold}Working Directory: 		${cyan}$(WORKDIR)${reset}"
	echo "${bold}Configuration File:		${cyan}$(CONFIG_FILE)${reset}"
	echo "${bold}Private Key File:		${cyan}$(PRIVATE_KEY)${reset}"
	echo "${bold}Certificate Signing Request:	${cyan}$(SIGNING_REQUEST)${reset}"
	echo "${bold}Certificate:			${cyan}$(CERTIFICATE)${reset}"
	echo "${bold}Fullchain:			${cyan}$(FULLCHAIN)${reset}"

	[[ ! -z "$(or $(DRY_RUN),$(DRY))" ]] && exit 0

	if [ ! -d "$(WORKDIR)" ]; then
		$(call message,📂,Creating Directory $(hl)$(WORKDIR)$(rs))
		mkdir -p "$(WORKDIR)"
	fi

	if [ ! -f "$(PRIVATE_KEY)" ]; then
		$(call message,📜,Creating Private Key $(hl)$(PRIVATE_KEY)$(rs))
		openssl ecparam -genkey -name "$(CURVE)" -out "$(PRIVATE_KEY)"
	fi

	if [ ! -f "$(CONFIG_FILE)" ]; then
		$(call message,📄,Creating Configuration File $(hl)$(CONFIG_FILE)$(rs))
		cat << EOF > "$(CONFIG_FILE)"
		[ req ]
		default_bits       = $(DEFAULT_BITS)
		prompt             = no
		default_md         = $(DEFAULT_MD)
		req_extensions     = v3_req
		distinguished_name = dn
		[ dn ]
		countryName  = $(COUNTRY)
		stateOrProvinceName = $(STATE)
		localityName  = $(LOCALITY)
		organizationName  = $(ORGANIZATION)
		organizationalUnitName = $(ORGANIZATION_UNIT)
		commonName = $(COMMON_NAME)
		[ v3_req ]
		subjectKeyIdentifier   = hash
		basicConstraints = critical, CA:FALSE
		keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
		extendedKeyUsage = serverAuth
		EOF

		ALT_NAMES=($(foreach n,$(SUBJECT_ALT_NAMES),'$(n)'))
		if [ "$${#ALT_NAMES[@]}" -gt 0 ]; then
			DNS_NAMES=()
			IP_ADDRS=()
			for name in $${ALT_NAMES[@]}; do
				if [[ "$$name" =~ '^[0-9\.]+$$' ]]; then
					IP_ADDRS+=("$$name")
				elif [[ "$$name" =~ '\:+' ]]; then
					IP_ADDRS+=("$$name")
				else
					DNS_NAMES+=("$$name")
				fi
			done
			cat << EOF >> "$(CONFIG_FILE)"
			subjectAltName = @alt_names
			[ alt_names ]
			$$(for i in {1..$${#DNS_NAMES[@]}}
			do
				echo DNS.$$i = $${DNS_NAMES[$$i]}
			done)
			$$(for i in {1..$${#IP_ADDRS[@]}}
			do
				echo IP.$$i = $${IP_ADDRS[$$i]}
			done)
			EOF
		fi
	fi

	if [ ! -f "$(SIGNING_REQUEST)" ]; then
		$(call message,📜,Creating Signing Request $(hl)$(SIGNING_REQUEST)$(rs))
		openssl req -new "-$(DEFAULT_MD)" -nodes -out "$(SIGNING_REQUEST)" -key "$(PRIVATE_KEY)" -config "$(CONFIG_FILE)"
	fi

	if [ ! -f "$(CERTIFICATE)" ]; then
		$(call message,📜,Creating Certificate $(hl)$(CERTIFICATE)$(rs))
		openssl x509 -req "-$(DEFAULT_MD)" -days "$(REQ_DAYS)" -in "$(SIGNING_REQUEST)" \
			-extfile "$(CONFIG_FILE)" -extensions v3_req -out "$(CERTIFICATE)" \
			-CA "$(CA_CERTIFICATE)" -CAkey "$(CA_PRIVATE_KEY)" -CAserial "$(CA_SERIAL)"
	fi

	if [ ! -f "$(FULLCHAIN)" ]; then
		$(call message,📜,Creating Fullchain Certificate $(hl)$(FULLCHAIN)$(rs))
		cat "$(CERTIFICATE)" "$(CA_CERTIFICATE)" > "$(FULLCHAIN)"
	fi
