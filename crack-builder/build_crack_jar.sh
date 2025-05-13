#!/bin/bash
set -e # Exit on error

v=( ${VERSION//./ } )
branch="${v[0]}.${v[1]}"
version_full="${v[0]}.${v[1]}.${v[2]}" # Renamed from 'version' to avoid conflict

echo "Runtime environment"
echo -e "branch: \t\t$branch"
echo -e "version_full: \t\t$version_full"
echo -e "http_proxy: \t\t$HTTP_PROXY"
echo -e "https_proxy: \t\t$HTTPS_PROXY"

# Ensure output directory exists
mkdir -p ./output

# Download source code
curl -o License.java -s https://raw.githubusercontent.com/elastic/elasticsearch/$branch/x-pack/plugin/core/src/main/java/org/elasticsearch/license/License.java
curl -o LicenseVerifier.java -s https://raw.githubusercontent.com/elastic/elasticsearch/$branch/x-pack/plugin/core/src/main/java/org/elasticsearch/license/LicenseVerifier.java
# curl -o XPackBuild.java -s https://raw.githubusercontent.com/elastic/elasticsearch/$branch/x-pack/plugin/core/src/main/java/org/elasticsearch/xpack/core/XPackBuild.java

# Edit License.java
sed -i '/void validate()/{h;s/validate/validate2/;x;G}' License.java
sed -i '/void validate()/ s/$/}/' License.java

# Edit LicenseVerifier.java
sed -i '/boolean verifyLicense(/{h;s/verifyLicense/verifyLicense2/;x;G}' LicenseVerifier.java
sed -i '/boolean verifyLicense(/ s/$/return true;}/' LicenseVerifier.java

# Edit XPackBuild.java
# sed -i 's/path.toString().endsWith(".jar")/false/g' XPackBuild.java

# Build class file
# Ensure all necessary JARs are on the classpath
CLASSPATH_JARS=$(find /usr/share/elasticsearch/lib /usr/share/elasticsearch/modules/x-pack-core -name "*.jar" -print0 | tr '\0' ':' | sed 's/:$//')

javac -cp "$CLASSPATH_JARS" LicenseVerifier.java
# javac -cp "$CLASSPATH_JARS" XPackBuild.java
javac -cp "$CLASSPATH_JARS" License.java

# Build jar file
cp /usr/share/elasticsearch/modules/x-pack-core/x-pack-core-$version_full.jar x-pack-core-$version_full.jar
unzip -q x-pack-core-$version_full.jar -d ./x-pack-core-$version_full
cp LicenseVerifier.class ./x-pack-core-$version_full/org/elasticsearch/license/
# cp XPackBuild.class ./x-pack-core-$version_full/org/elasticsearch/xpack/core/
cp License.class ./x-pack-core-$version_full/org/elasticsearch/license/
jar -cf x-pack-core-$version_full.crack.jar -C x-pack-core-$version_full/ .
rm -rf x-pack-core-$version_full

# Copy output
echo "Copying cracked JAR to ./output/"
cp x-pack-core-$version_full.crack.jar ./output/
# Optional: copy other files if needed for debugging
# cp LicenseVerifier.* ./output
# cp XPackBuild.* ./output

echo "Cracked JAR build complete: ./output/x-pack-core-$version_full.crack.jar"