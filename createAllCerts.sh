#!/bin/bash
source .env
printf "\n\n############\n"
echo     "Set ENV !"
printf "############\n\n"
LOCAL_PATH=$(pwd)
printf "\n\n######################\n"
echo     "Remove all certifs !"
printf "######################\n\n"
sudo rm -rf CA kafka zookeeper clients
sync
mkdir -p zookeeper kafka/broker1 kafka/broker2 clients

printf "\n\n######################\n"
echo     "Create CA"
printf "######################\n\n"

mkdir -p $SERVER_CA_PATH
cd $SERVER_CA_PATH

###Create CA and server keystore/truststore###
openssl req -new -x509 -keyout ca-key -out ca-cert -days $VALIDITY -subj $CA_INFO -passout pass:$SSLPASSPHRASE
cd $LOCAL_PATH

printf "\n\n######################\n"
echo    "Create Broker 1 certifs"
printf "######################\n\n"

mkdir -p $KAFKA_SSL_BROKER1
cd $KAFKA_SSL_BROKER1

###Create CA and server keystore/truststore###
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER1_HOST -validity $VALIDITY -genkey -dname $CERTIFICATE_INFO_BROKER1 -keypass $SSLPASSPHRASE -storepass $SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.truststore.jks -alias CARoot -import -file $SERVER_CA_PATH/ca-cert -storepass $SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER1_HOST -certreq -file cert-file-$KAFKA_BROKER1_HOST -storepass $SSLPASSPHRASE 
openssl x509 -req -CA $SERVER_CA_PATH/ca-cert -CAkey $SERVER_CA_PATH/ca-key -in cert-file-$KAFKA_BROKER1_HOST -out cert-signed-$KAFKA_BROKER1_HOST -days $VALIDITY -CAcreateserial -passin pass:$SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.keystore.jks -alias CARoot -import -file $SERVER_CA_PATH/ca-cert -storepass $SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER1_HOST -import -file cert-signed-$KAFKA_BROKER1_HOST -storepass $SSLPASSPHRASE 
cd $LOCAL_PATH

printf "\n\n##########################\n"
echo    "Create Broker 2 certifs"
printf "##########################\n\n"

mkdir -p $KAFKA_SSL_BROKER2
cd $KAFKA_SSL_BROKER2

###Create CA and server keystore/truststore###
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER2_HOST -validity $VALIDITY -genkey -dname $CERTIFICATE_INFO_BROKER2 -keypass $SSLPASSPHRASE -storepass $SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.truststore.jks -alias CARoot -import -file $SERVER_CA_PATH/ca-cert -storepass $SSLPASSPHRASE
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER2_HOST -certreq -file cert-file-$KAFKA_BROKER2_HOST -storepass $SSLPASSPHRASE 
openssl x509 -req -CA $SERVER_CA_PATH/ca-cert -CAkey $SERVER_CA_PATH/ca-key -in cert-file-$KAFKA_BROKER2_HOST -out cert-signed-$KAFKA_BROKER2_HOST -days $VALIDITY -CAcreateserial -passin pass:$SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.keystore.jks -alias CARoot -import -file $SERVER_CA_PATH/ca-cert -storepass $SSLPASSPHRASE 
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER2_HOST -import -file cert-signed-$KAFKA_BROKER2_HOST -storepass $SSLPASSPHRASE 
echo "Add broker2 certificate to broker1 truststore"
keytool -noprompt -keystore $KAFKA_SSL_BROKER1/kafka.server.truststore.jks -alias $KAFKA_BROKER2_HOST -import -file cert-signed-$KAFKA_BROKER2_HOST -storepass $SSLPASSPHRASE 
echo "Add broker1 certificate to broker2 truststore"
keytool -noprompt -keystore kafka.server.truststore.jks -alias $KAFKA_BROKER1_HOST -import -file $KAFKA_SSL_BROKER1/cert-signed-$KAFKA_BROKER1_HOST -storepass $SSLPASSPHRASE 
echo "Add broker2 certificate to broker1 keyStore"
keytool -noprompt -keystore $KAFKA_SSL_BROKER1/kafka.server.keystore.jks -alias $KAFKA_BROKER2_HOST -import -file cert-signed-$KAFKA_BROKER2_HOST -storepass $SSLPASSPHRASE 
echo "Add broker1 certificate to broker2 keyStore"
keytool -noprompt -keystore kafka.server.keystore.jks -alias $KAFKA_BROKER1_HOST -import -file $KAFKA_SSL_BROKER1/cert-signed-$KAFKA_BROKER1_HOST -storepass $SSLPASSPHRASE 
cd $LOCAL_PATH


printf "\n\n###############################\n"
echo    "Create default client certifs"
printf "###############################\n\n"


if [ -d "$USERNAME" ]; then
	echo "$USERNAME already exist, please choose anothe name or remove certifs : sudo rm -rf $LOCAL_PATH/clients/$USERNAME"
else
mkdir -p $USERNAME_PATH
	cd $USERNAME_PATH

	###Create client keystore and truststore###
	keytool -noprompt -keystore kafka.client.keystore.jks -alias $USERNAME -validity $VALIDITY -genkey -dname $CLIENT_CERTIFICATE_INFO -keypass $CLIENT_SSLPASSPHRASE -storepass $CLIENT_SSLPASSPHRASE 
	keytool -noprompt -keystore kafka.client.truststore.jks -alias CARoot -import -file $SERVER_CA_PATH/ca-cert -storepass $CLIENT_SSLPASSPHRASE 
	keytool -noprompt -keystore kafka.client.keystore.jks -alias $USERNAME -certreq -file cert-file-client-$USERNAME -storepass $CLIENT_SSLPASSPHRASE 
	openssl x509 -req -CA $SERVER_CA_PATH/ca-cert -CAkey $SERVER_CA_PATH/ca-key -in cert-file-client-$USERNAME -out cert-signed-client-$USERNAME -days $VALIDITY -CAcreateserial -passin pass:$SSLPASSPHRASE 
	echo "Add client certificate to broker1 truststore"
	###Add client certificate to broker1 truststore###
	keytool -keystore $KAFKA_SSL_BROKER1/kafka.server.truststore.jks -alias $USERNAME -import -file cert-signed-client-$USERNAME -storepass $SSLPASSPHRASE 
	###Add client certificate to broker2 truststore###
	echo "Add client certificate to broker2 truststore"
	keytool -keystore $KAFKA_SSL_BROKER2/kafka.server.truststore.jks -alias $USERNAME -import -file cert-signed-client-$USERNAME -storepass $SSLPASSPHRASE 
	
	echo "security.protocol=SSL" > $CURRENT_PATH/clients/$USERNAME/client-ssl.properties
	echo "ssl.truststore.location=$CURRENT_PATH/clients/$USERNAME/kafka.client.truststore.jks" >> $CURRENT_PATH/clients/$USERNAME/client-ssl.properties
	echo "ssl.truststore.password=$CLIENT_SSLPASSPHRASE" >> $CURRENT_PATH/clients/$USERNAME/client-ssl.properties
	echo "ssl.keystore.location=$CURRENT_PATH/clients/$USERNAME/kafka.client.keystore.jks" >> $CURRENT_PATH/clients/$USERNAME/client-ssl.properties
	echo "ssl.keystore.password=$CLIENT_SSLPASSPHRASE" >> $CURRENT_PATH/clients/$USERNAME/client-ssl.properties
	echo "ssl.key.password=$CLIENT_SSLPASSPHRASE" >> $CURRENT_PATH/clients/$USERNAME/client-ssl.properties	

fi

