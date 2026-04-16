CERTS_DIR 			?= ~/.ssl
AVAILABLE_SIZES		:= 256 384 512
KEY_SIZE			?= $(or $(SIZE),384)
CURVE				:= secp$(KEY_SIZE)r1
HASH				:= SHA$(KEY_SIZE)
DEFAULT_BITS 		?= $(or $(BITS),4096)
REQ_DAYS 			?= $(or $(DAYS),3650)
COUNTRY 			?= $(or $(CT),FR)
STATE 				?= $(or $(ST),Paris)
LOCALITY 			?= $(or $(LO),Paris)
ORGANIZATION 		?= $(or $(OG),Local)
ORGANIZATION_UNIT 	?= $(or $(OU),IT)

ifeq (,$(filter $(KEY_SIZE),$(AVAILABLE_SIZES)))
$(error Invalid key size '$(KEY_SIZE)', must be one of '$(AVAILABLE_SIZES)')
endif

define gen_cert
CERTIFICATE="$(1)"
DIRECTORY="$(2)"
COMMON_NAME="$(3)"
KEY="$(subst .crt,.key,$(1))"
CONFIG="$(subst .crt,.cnf,$(1))"
REQUEST="$(subst .crt,.csr,$(1))"
SERIAL="$(subst .crt,.srl,$(1))"
FULLCHAIN="$(subst .crt,.fullchain.crt,$(1))"
IS_CA="$(4)"
ALT_NAMES=($(foreach n,$(or $(SAN),$(ALT_NAMES)),'$(n)'))
CA_CERT="$(5)"
CA_KEY="$$( echo "$${CA_CERT}" | sed 's/.crt/.key/' )"
CA_SERIAL="$$( echo "$${CA_CERT}" | sed 's/.crt/.srl/' )"

[[ "$${IS_CA}" == "true" ]] && title="Certification Authority" || title="Certificate"

echo "${bold}${underline}$${title}${reset}"
echo "${bold}Common Name: 				${cyan}$${COMMON_NAME}${reset}"
echo "${bold}Directory: 				${cyan}$${DIRECTORY}${reset}"
echo "${bold}Configuration:				${cyan}$${CONFIG}${reset}"
echo "${bold}Private Key:				${cyan}$${KEY}${reset}"
echo "${bold}Signing Request:			${cyan}$${REQUEST}${reset}"
echo "${bold}Certificate:				${cyan}$${CERTIFICATE}${reset}"
if [[ "$${IS_CA}" == "true" ]]; then
	echo "${bold}Serial:					${cyan}$${SERIAL}${reset}"
else
	echo "${bold}Fullchain Certificate:			${cyan}$${FULLCHAIN}${reset}"
	if [[ ! -z "$${ALT_NAMES}" ]]; then
		echo "${bold}Subject Alt Names:			${cyan}$${ALT_NAMES}${reset}"
	fi
	echo "${bold}Certification Authority Certificate:	${cyan}$${CA_CERT}${reset}"
	echo "${bold}Certification Authority Private Key:	${cyan}$${CA_KEY}${reset}"
	echo "${bold}Certification Authority Serial:		${cyan}$${CA_SERIAL}${reset}"
fi

[[ ! -z "$(or $(DRY),$(DRY_RUN))" ]] && exit 0

if [ ! -d "$${DIRECTORY}" ]; then
	$(call message,📂,Creating Directory $(hl)$${DIRECTORY}$(rs))
	mkdir -p "$${DIRECTORY}"
fi

if [ ! -f "$${KEY}" ]; then
	$(call message,📜,Creating Private Key $(hl)$${KEY}$(rs))
	openssl ecparam -genkey -name "$(CURVE)" -out "$${KEY}"
fi

if [ ! -f "$${CONFIG}" ]; then
	$(call message,📄,Creating Configuration File $(hl)$${CONFIG}$(rs))
	cat <<-EOF > "$${CONFIG}"
	[ req ]
	default_bits       = $(DEFAULT_BITS)
	prompt             = no
	default_md         = $(HASH)
	req_extensions     = v3_req
	distinguished_name = dn
	[ dn ]
	countryName  = $(COUNTRY)
	stateOrProvinceName = $(STATE)
	localityName  = $(LOCALITY)
	organizationName  = $(ORGANIZATION)
	organizationalUnitName = $(ORGANIZATION_UNIT)
	commonName = $${COMMON_NAME}
	[ v3_req ]
	subjectKeyIdentifier = hash
	EOF

	if [[ "$${IS_CA}" == "true" ]]; then
		cat <<EOF >> "$${CONFIG}"
		basicConstraints = critical,CA:TRUE
		keyUsage = critical, digitalSignature, cRLSign, keyCertSign
		EOF
	else
		cat <<EOF >> "$${CONFIG}"
		basicConstraints = critical, CA:FALSE
		keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
		extendedKeyUsage = serverAuth
		EOF
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
			cat << EOF >> "$${CONFIG}"
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
fi

if [ ! -f "$${REQUEST}" ]; then
	$(call message,📜,Creating Signing Request $(hl)$${REQUEST}$(rs))
	openssl req -new "-$(HASH)" -nodes -out "$${REQUEST}" -key "$${KEY}" -config "$${CONFIG}"
fi

if [ ! -f "$${CERTIFICATE}" ]; then
	$(call message,📜,Creating Certificate $(hl)$${CERTIFICATE}$(rs))
	[[ "$${IS_CA}" == "true" ]] && params=(-signkey "$${KEY}") \
		|| params=(-CA "$${CA_CERT}" -CAkey "$${CA_KEY}" -CAserial "$${CA_SERIAL}")
	openssl x509 -req "-$(HASH)" -days "$(REQ_DAYS)" -in "$${REQUEST}" \
		-extfile "$${CONFIG}" $${params[@]} -out "$${CERTIFICATE}"
fi

if [[ "$${IS_CA}" == "true" ]] && [[ ! -f "$${SERIAL}" ]]; then
	$(call message,📜,Creating Serial $(hl)$${SERIAL}$(rs))
	echo "01" > "$${SERIAL}"
fi

if [[ "$${IS_CA}" == "false" ]] && [[ ! -f "$${FULLCHAIN}" ]]; then
	$(call message,📜,Creating Fullchain Certificate $(hl)$${FULLCHAIN}$(rs))
	cat "$${CERTIFICATE}" "$${CA_CERT}" > "$${FULLCHAIN}"
fi
endef

$(CERTS_DIR)/%/CA.crt: # 📜 Generates a self-signed certification authority certificate
	$(call gen_cert,$@,$(@D),$(*F),true)

$(CERTS_DIR)/%.crt: # 📜 Generates a self-signed certificate
	if [[ "$(@D)" == "$(call path,$(CERTS_DIR))" ]]; then
		$(call message,⚠️ ,$(bold)Invalid certificate directory $(yellow)$(@D)$(rs) $(bold)it must be a $(underline)subfolder$(rs))
		exit 1
	fi
	CA="$(call path,$(or $(CA),$(AUTHORITY),$(subst $(@F),CA.crt,$@)))"
	$(MAKE) "$${CA}"
	$(call gen_cert,$@,$(@D),$(*F),false,$${CA})
