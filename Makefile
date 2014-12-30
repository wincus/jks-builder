AUTHOR=wincus
KEYTOOL=$(shell which keytool)
OPENSSL=$(shell which openssl)

ifeq ($(KEYTOOL),)
$(error keytool not found)
endif

ifeq ($(OPENSSL),)
$(error openssl not found)
endif

vpath %.req reqs
vpath %.csr csrs
vpath %.key keys
vpath %.pem pems
vpath %.p12 p12s
vpath %.crl crls
#vpath %.jks jkss

initca: test dirs serial index.txt crlnumber secret
	$(OPENSSL) req -batch -config openssl.conf -days 3650 -x509 -newkey rsa:2048 -out pems/cacert.pem -outform PEM -keyout keys/cakey.pem -passout file:secret -subj "/OU=OrgName LAB/O=Organization/L=MZA/ST=MZA/C=AR/CN=CA Authority"

test:
	$(info It should not be a ca created ...)
	@test ! -f pems/cacert.pem

itest:
	$(info It should be a ca created ...)
	@test -f pems/cacert.pem

secret:
	$(OPENSSL) rand -base64 24 > secret
	cat secret | tee -a secret #litle hack in here

serial:
	echo '01' > serial

index.txt:
	touch index.txt

crlnumber:
	touch crlnumber

dirs:
	mkdir -p reqs csrs keys pems p12s crls jkss
	chmod go-rwx keys

cleanca:
	$(warning all data will be lost! Press CTRL-C to quit)
	$(warning or press any other key to continue)
	$(shell read variable)
	rm -rf reqs csrs keys pems p12s crls jkss
	rm -rf serial*
	rm -rf index.txt*
	rm -rf crlnumber
	rm -rf secret

.PHONY: initca test itest dirs cleanca

# dependency tree:
#
#               cn.req
#                 + +
#                 | +-----> cn.key
#                 v            +
#               cn.csr         |
#                 +            +------> cn.p12
#                 +---> cn.pem +------>   +
#                                         +---> cn.jks
#
%.req: itest
	$(shell test -f reqs/$@ || touch reqs/$@)

%.csr %.key: %.req
	$(shell test -f keys/$*.key || $(OPENSSL) req -batch -config openssl.conf -newkey rsa:1024 -days 1800 -out csrs/$*.csr -keyout keys/$*.key -subj "/C=AR/ST=MZA/CN=$*" -passout file:secret)

%.pem: %.csr
	$(shell test -f pems/$*.pem || $(OPENSSL) ca -batch -config openssl.conf -notext -in csrs/$*.csr -out pems/$*.pem -passin file:secret)

%.p12: %.pem %.key
	$(OPENSSL) pkcs12 -export -in pems/$*.pem -inkey keys/$*.key -passin file:secret -out p12s/$*.p12 -name $* -CAfile pems/cacert.pem -chain -passout file:secret

%.jks: %.p12
ifdef keystorepass
	rm -rf jkss/$*.jks #clean old keystore
	$(KEYTOOL) -noprompt -importkeystore -srckeystore p12s/$*.p12 -srcstorepass $(shell head -1 secret) -srcstoretype PKCS12 -destkeystore jkss/$*.jks -deststoretype JKS -deststorepass $(keystorepass) -destkeypass $(keystorepass) -alias $*
	$(KEYTOOL) -noprompt -import -trustcacerts -alias authenware-ca -file pems/cacert.pem -keystore jkss/$*.jks -storepass $(keystorepass)
else
	$(error A export key must be supplied!)
endif
