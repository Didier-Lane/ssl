SSL_DIR 			?= ~/.ssl
TLS_ALGORITHMS		:= ecdsa_secp256r1_sha256 ecdsa_secp384r1_sha384 ecdsa_secp521r1_sha512 ed25519
ALGORITHM			:= $(or $(ALG),$(A),ecdsa_secp384r1_sha384)

ifeq ($(filter $(ALGORITHM),$(TLS_ALGORITHMS)),)
$(error Invalid ALGORITHM '$(ALGORITHM)' must be one of '$(TLS_ALGORITHMS)')
endif

HASH				!= echo "$(ALGORITHM)" | grep -Eo 'sha[0-9]+'

ifeq ($(HASH),)
override HASH		:= sha512
endif

CURVE				!= echo "$(ALGORITHM)" | grep -Eo 'secp[0-9]+r1'

REQ_DAYS 			:= $(or $(DAYS),$(D),3650)
COUNTRY 			:= $(or $(CT),$(C),FR)
STATE 				:= $(or $(ST),$(S),Paris)
LOCALITY 			:= $(or $(LO),$(L),Paris)
ORGANIZATION 		:= $(or $(OG),$(O),Local)
ORGANIZATION_UNIT 	:= $(or $(OU),$(U),IT)

define gen_cert
CERTIFICATE="$(1)"
DIRECTORY="$(2)"
COMMON_NAME="$(or $(COMMON_NAME),$(CNAME),$(CN),$(3))"
KEY="$(subst .crt,.key,$(1))"
CONFIG="$(subst .crt,.cnf,$(1))"
REQUEST="$(subst .crt,.csr,$(1))"
SERIAL="$(subst .crt,.srl,$(1))"
KEY_AND_CERT="$(subst .crt,-key-and-crt.pem,$(1))"
FULLCHAIN="$(subst .crt,.fullchain.crt,$(1))"
IS_CA="$(4)"
ALT_NAMES=($(foreach n,$(or $(SAN),$(ALT_NAMES)),'$(n)'))
CA_CERT="$(5)"
CA_KEY="$$( echo "$${CA_CERT}" | sed 's/.crt/.key/' )"
CA_SERIAL="$$( echo "$${CA_CERT}" | sed 's/.crt/.srl/' )"

title="Certificate"

if [[ "$${IS_CA}" == "true" ]]; then
	COMMON_NAME="$(or $(CA_COMMON_NAME),$(CA_NAME),$(CA_CN),$${COMMON_NAME})"
	title="Certification Authority"
fi

echo "$(bold)$(underline)$${title}$(rs)"
echo "Signature Algorithm: 			$(hl)$(ALGORITHM)$(rs)"
echo "Common Name: 				$(hl)$${COMMON_NAME}$(rs)"
echo "Directory: 				$(hl)$${DIRECTORY}$(rs)"
echo "Configuration:				$(hl)$${CONFIG}$(rs)"
echo "Private Key:				$(hl)$${KEY}$(rs)"
echo "Signing Request:			$(hl)$${REQUEST}$(rs)"
echo "Certificate:				$(hl)$${CERTIFICATE}$(rs)"
echo "Private Key and Certificate:		$(hl)$${KEY_AND_CERT}$(rs)"
if [[ "$${IS_CA}" == "true" ]]; then
	echo "Serial:					$(hl)$${SERIAL}$(rs)"
else
	echo "Fullchain Certificate:			$(hl)$${FULLCHAIN}$(rs)"
	if [[ ! -z "$${ALT_NAMES}" ]]; then
		echo "Subject Alt Names:			$(hl)$${ALT_NAMES}$(rs)"
	fi
	echo "Certification Authority Certificate:	$(hl)$${CA_CERT}$(rs)"
	echo "Certification Authority Private Key:	$(hl)$${CA_KEY}$(rs)"
	echo "Certification Authority Serial:		$(hl)$${CA_SERIAL}$(rs)"
fi

[[ ! -z "$(or $(DRY),$(DRY_RUN))" ]] && exit 0

if [ ! -d "$${DIRECTORY}" ]; then
	$(call message,📂,Creating Directory $(hl)$${DIRECTORY}$(rs))
	mkdir -p "$${DIRECTORY}"
fi

if [ ! -f "$${CONFIG}" ]; then
	$(call message,📄,Creating Configuration File $(hl)$${CONFIG}$(rs))
	cat <<-EOF > "$${CONFIG}"
	[ req ]
	default_bits       = 4096
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
		basicConstraints = critical, CA:TRUE
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
			EOF
			if [ "$${#DNS_NAMES[@]}" -gt 0 ]; then
				for i in {1..$${#DNS_NAMES[@]}}; do
					echo "DNS.$$i = $${DNS_NAMES[$$i]}" >> "$${CONFIG}"
				done
			fi
			if [ "$${#IP_ADDRS[@]}" -gt 0 ]; then
				for i in {1..$${#IP_ADDRS[@]}}; do
					echo "IP.$$i = $${IP_ADDRS[$$i]}" >> "$${CONFIG}"
				done
			fi
		fi
	fi
fi

if [ ! -f "$${KEY}" ]; then
	$(call message,📜,Creating Private Key $(hl)$${KEY}$(rs))
	if [[ "$(ALGORITHM)" == "ed25519" ]]; then
		openssl genpkey \
			-algorithm ED25519 \
			-out "$${KEY}"
	else
		openssl ecparam -genkey \
			-name "$(CURVE)" \
			-out "$${KEY}"
	fi
fi

if [ ! -f "$${REQUEST}" ]; then
	$(call message,📜,Creating Signing Request $(hl)$${REQUEST}$(rs))
	openssl req -new \
		"-$(HASH)" \
		-key "$${KEY}" \
		-config "$${CONFIG}" \
		-out "$${REQUEST}"
fi

if [ ! -f "$${CERTIFICATE}" ]; then
	$(call message,📜,Creating Certificate $(hl)$${CERTIFICATE}$(rs))
	if [[ "$${IS_CA}" == "true" ]]; then
		params=(-signkey "$${KEY}")
	else
		params=(-CA "$${CA_CERT}" -CAkey "$${CA_KEY}" -CAserial "$${CA_SERIAL}")
	fi
	openssl x509 -req \
		"-$(HASH)" \
		-days "$(REQ_DAYS)" \
		-in "$${REQUEST}" \
		-extensions v3_req \
		-extfile "$${CONFIG}" \
		$${params[@]} \
		-out "$${CERTIFICATE}"
fi

if [[ "$${IS_CA}" == "true" ]] && [[ ! -f "$${SERIAL}" ]]; then
	$(call message,📜,Creating Serial $(hl)$${SERIAL}$(rs))
	echo "01" > "$${SERIAL}"
fi

if [[ "$${IS_CA}" == "false" ]] && [[ ! -f "$${FULLCHAIN}" ]]; then
	$(call message,📜,Creating Fullchain Certificate $(hl)$${FULLCHAIN}$(rs))
	cat "$${CERTIFICATE}" "$${CA_CERT}" > "$${FULLCHAIN}"
fi

if [ ! -f "$${KEY_AND_CERT}" ]; then
	$(call message,📜,Creating Private Key and Certificate file $(hl)$${KEY_AND_CERT}$(rs))
	cat "$${KEY}" "$${CERTIFICATE}" > "$${KEY_AND_CERT}"
fi

if [[ "$${IS_CA}" == "false" ]]; then
	$(call message,🔍,Verifying CA $(hl)$${CA_CERT}$(rs) and certificate $(hl)$${CERTIFICATE}$(rs))
	openssl verify -verbose -CAfile "$${CA_CERT}" "$${CERTIFICATE}"
fi

$(call message,📜,Displaying Certificate $(hl)$${CERTIFICATE}$(rs))
openssl x509 -noout -text -in "$${CERTIFICATE}"
endef

$(SSL_DIR)/%/CA.crt: # 📜 Generates a self-signed certification authority certificate
	$(call gen_cert,$@,$(@D),$(*F),true)

$(SSL_DIR)/%.crt: # 📜 Generates a self-signed certificate
	if [[ "$(@D)" == "$(call path,$(SSL_DIR))" ]]; then
		$(call message,⚠️ ,$(bold)Invalid certificate directory $(yellow)$(@D)$(rs) $(bold)it must be a $(underline)subfolder$(rs))
		exit 1
	fi
	CA="$(call path,$(or $(CA),$(AUTHORITY),$(subst $(@F),CA.crt,$@)))"
	$(MAKE) "$${CA}"
	$(call gen_cert,$@,$(@D),$(*F),false,$${CA})
