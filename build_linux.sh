apt-get install libssl-dev
wget http://dist.schmorp.de/libev/libev-4.24.tar.gz
tar xvf libev-4.24.tar.gz
 cd libev-4.24/
./configure
make
make install
cd ..
wget https://www.aerospike.com/artifacts/aerospike-client-c/4.3.15/aerospike-client-c-libev-4.3.15.ubuntu14.04.x86_64.tgz
tar xvf aerospike-client-c-libev-4.3.15.ubuntu14.04.x86_64.tgz 
dpkg -i aerospike-client-c-libev-4.3.15.ubuntu14.04.x86_64/aerospike-client-c-libev-devel-4.3.15.ubuntu14.04.x86_64.deb
gcc -I/usr/share/nginx/luajit/include/luajit-2.1 -O0 -g3 -Wall -c -fmessage-length=0 -MMD -MP -MF"as_lua.d" -MT"as_lua.d" -o "./as_lua.o" "as_lua.c" -std=gnu99 -g -rdynamic -Wall -fno-common -fno-strict-aliasing -fPIC -DMARCH_x86_64 -D_FILE_OFFSET_BITS=64 -D_REENTRANT -D_GNU_SOURCE
gcc -DAS_USE_LIBEV  -shared -o "as_lua.so"  ./as_lua.o -laerospike -lssl -lcrypto -lpthread -lrt -lm -lev
cp as_lua.so /usr/share/nginx/luajit/lib/lua/5.1/as_lua.so
