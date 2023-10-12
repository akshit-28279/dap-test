
#include <lua.h>                               /* Always include this */
#include <lauxlib.h>                           /* Always include this */
#include <lualib.h>                            /* Always include this */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

#include <aerospike/aerospike.h>
#include <aerospike/aerospike_key.h>
#include <aerospike/as_error.h>
#include <aerospike/as_key.h>
#include <aerospike/as_record.h>
#include <aerospike/as_record_iterator.h>
#include <aerospike/as_iterator.h>
#include <aerospike/as_status.h>
#include <aerospike/as_arraylist.h>
#include <aerospike/as_arraylist_iterator.h>
#include <aerospike/as_list.h>
#include <aerospike/as_map.h>
#include <aerospike/as_monitor.h>

// Allow only one global aerospike instance.
aerospike as;
as_monitor monitor;
//static as_monitor monitor;

static int launchEvent = 0;

/*static void my_listener(as_error* err, void* udata, as_event_loop* event_loop);

static void my_listener(as_error* err, void* udata, as_event_loop* event_loop)
{

       if (err) {
           return;
       }
       printf("Test  Command succeeded\n");
}*/

static as_record add_bins_to_rec(lua_State *L, int index, int numBins)
{
    as_record rec;
    as_record_init(&rec, numBins);

    // Push another reference to the table on top of the stack (so we know
    // where it is, and this function can work for negative, positive and
    // pseudo indices
    lua_pushvalue(L, index);
    // stack now contains: -1 => table
    lua_pushnil(L);
    // stack now contains: -1 => nil; -2 => table
    while (lua_next(L, -2))
    {
        // stack now contains: -1 => value; -2 => key; -3 => table
        // copy the key so that lua_tostring does not modify the original
        lua_pushvalue(L, -2);
        // stack now contains: -1 => key; -2 => value; -3 => key; -4 => table
        const char *binName = lua_tostring(L, -1);

        // add to record
        if (lua_isnumber(L, -2)){
        	int intValue = lua_tointeger(L, -2);
        	as_record_set_int64(&rec, binName, intValue);

        } else if (lua_isstring(L, -2)){
        	const char *value = lua_tostring(L, -2);
        	as_record_set_str(&rec, binName, value);
        } else if (lua_istable(L, -2)){
	    	// make a as_list and populate it
        	as_arraylist *list = as_arraylist_new(3, 3);
            
        	lua_pushvalue(L, -2);
        	lua_pushnil(L);
        	    // This is needed for it to even get the first value
        	    while (lua_next(L, -2))
        	    {
        	    	lua_pushvalue(L, -2);
        	    	//const char *key = lua_tostring(L, -1);
        	    	const char *value = lua_tostring(L, -2);
        	    	// populate the as_list
        	    	as_arraylist_append_str(list, value);
        	    	//printf("%s => %s\n", key, value);
        	        lua_pop(L, 2);
        	    }
        	lua_pop(L, 1);
            
	    	// put the list in a bin
        	as_record_set_list(&rec, binName, (as_list*)as_val_reserve(list));
        }
        // pop value + copy of key, leaving original key
        lua_pop(L, 2);
        // stack now contains: -1 => key; -2 => table
    }

    // stack now contains: -1 => table (when lua_next returns 0 it pops the key
    // but does not push anything.)
    // Pop table
    lua_pop(L, 1);
    // Stack is now the same as it was on entry to this function
    return rec;
}



static as_operations add_bins_to_increment(lua_State *L, int index, int numBins)
{
	as_operations ops;
	as_operations_init(&ops, numBins);

    // Push another reference to the table on top of the stack (so we know
    // where it is, and this function can work for negative, positive and
    // pseudo indices
    lua_pushvalue(L, index);
    // stack now contains: -1 => table
    lua_pushnil(L);
    // stack now contains: -1 => nil; -2 => table
    while (lua_next(L, -2))
    {
        // stack now contains: -1 => value; -2 => key; -3 => table
        // copy the key so that lua_tostring does not modify the original
        lua_pushvalue(L, -2);
        // stack now contains: -1 => key; -2 => value; -3 => key; -4 => table
        const char *binName = lua_tostring(L, -1);
        int intValue = lua_tointeger(L, -2);
        
        //printf("Bin:%s, value:%d\n", binName, intValue);
        
    	//add an operation for each bin
    	as_operations_add_incr(&ops, binName, intValue);
        // pop value + copy of key, leaving original key
        lua_pop(L, 2);
        // stack now contains: -1 => key; -2 => table
    }

    // stack now contains: -1 => table (when lua_next returns 0 it pops the key
    // but does not push anything.)
    // Pop table
    lua_pop(L, 1);
    // Stack is now the same as it was on entry to this function
    return ops;
}


static int connect(lua_State *L){
	const char *hostName = luaL_checkstring(L, 1);
	int port = lua_tointeger(L, 2);
	as_error err;

	// Configuration for the client.
	as_config config;
	as_config_init(&config);

	// Add a seed host for cluster discovery.
	//config.hosts[0].addr = hostName;
	//config.hosts[0].port = port;
	as_config_add_host(&config, hostName, port);

	config.async_max_conns_per_node = 100;

	// The Aerospike client instance, initialized with the configuration.
	aerospike_init(&as, &config);

  	//as_event_create_loops(1);
	
	// Connect to the cluster.
	aerospike_connect(&as, &err);

	/* Push the return */
	lua_pushnumber(L, err.code);
	lua_pushstring(L, err.message);
	lua_pushlightuserdata(L, &as);

	return 3;
}

static int disconnect(lua_State *L){
	aerospike* as = lua_touserdata(L, 1);
	as_error err;
	aerospike_close(as, &err);
	lua_pushnumber(L, err.code);
	lua_pushstring(L, err.message);
	return 2;
}
static int get(lua_State *L){
	//printf("-get-\n");
	aerospike* as = lua_touserdata(L, 1);
	const char* nameSpace = luaL_checkstring(L, 2);
	const char* set = luaL_checkstring(L, 3);
	const char* keyString = luaL_checkstring(L, 4);
	//printf("key-:%s\n", keyString);
	as_record* rec = NULL;
	as_key key;
	as_error err;
	as_key_init(&key, nameSpace, set, keyString);

	// Read the test record from the database.
	aerospike_key_get(as, &err, NULL, &key, &rec);

	// Push the error code
	lua_pushnumber(L, err.code);

	// Push the error message
	lua_pushstring(L, err.message);

	// Create an new table and push it
	if ( err.code == AEROSPIKE_OK){
        
		lua_newtable(L); /* create table to hold Bins read */
		/*
		 * iterate through bin and add the bin name
		 * and value to the table
		 */
		as_record_iterator it;
		as_record_iterator_init(&it, rec);

		while (as_record_iterator_has_next(&it)) {
		    as_bin *bin        = as_record_iterator_next(&it);
		    as_val *value      = (as_val*)as_bin_get_value(bin);
            char * binName = as_bin_get_name(bin);
            
		    int bin_type = as_val_type(value); //Bin Type

		    switch (bin_type){
		    case AS_INTEGER:
                   
		    	//printf("--integer-%s-\n", binName);
			    lua_pushstring(L, binName); //Bin name
		    	lua_pushnumber(L, as_integer_get(as_integer_fromval(value)));
		    	//printf("--integer-end-\n");
		    	break;
		    case AS_DOUBLE:
                   
		    	//printf("--double-%s-\n", binName);
			    lua_pushstring(L, binName); //Bin name
		    	lua_pushnumber(L, as_double_get(as_double_fromval(value)));
		    	//printf("--double-end-\n");
		    	break;
		    case AS_STRING:
			    lua_pushstring(L, binName); //Bin name
		    	lua_pushstring(L, as_val_tostring(value));
		    	//printf("--string-end-\n");
		    	break;
		    case AS_LIST:
		    	//printf("--list-%s-\n", binName);
			    lua_pushstring(L, binName); //Bin name
		    	// Iterate through arraylist populating table
		    	as_list* p_list = as_list_fromval(value);
		    	as_arraylist_iterator it;
		    	as_arraylist_iterator_init(&it, (const as_arraylist*)p_list);
                    
                // create a Lua inner table table for the "List"
		    	lua_newtable(L);
                    
		    	int count = 0;
		    	// See if the elements match what we expect.
		    	while (as_arraylist_iterator_has_next(&it)) {
		    		const as_val* p_val = as_arraylist_iterator_next(&it);
		    		//Assume string
		    		char* p_str = as_val_tostring(p_val);
                    lua_pushnumber(L, count); // table[i]
			    	lua_pushstring(L, p_str); //Value
                    //printf("%d => %s\n", count, p_str);
			    	count++;
			    	lua_settable(L, -3);
		    	}
                //printf("--list-end-\n");
                break;
		    }
		    //printf("--settable-\n");
		    lua_settable(L, -3);
		    //printf("--settable-end-\n");
		}
	}
	as_record_destroy(rec);
	as_key_destroy(&key);
	return 3;
}



static int put(lua_State *L){

	//Cluster
	aerospike* as = lua_touserdata(L, 1);

	//Namespace
	const char* nameSpace = luaL_checkstring(L, 2);

	//Set
	const char* set = luaL_checkstring(L, 3);

	//Key as string
	const char* keyString = luaL_checkstring(L, 4);

	// Number of bins.
	const int numBins = lua_tointeger(L, 5);

	//Bins
	as_record rec = add_bins_to_rec(L, 6, numBins);

	// Create key
	as_key key;
	as_error err;
	as_key_init(&key, nameSpace, set, keyString);

	// Write record
	
  	/*if( launchEvent == 0 ) {
  		as_event_create_loops(100);
  		launchEvent++;
  	}*/

	aerospike_key_put(as, &err, NULL, &key, &rec);
	
       // printf("Command failed: %d %s\n", 0, err);	
    
    as_record_destroy(&rec);
	// Return status
	lua_pushnumber(L, err.code );
	lua_pushstring(L, err.message);
	return 2;

}


static int increment(lua_State *L){
	as_error err;
	aerospike* as = lua_touserdata(L, 1);
	const char* nameSpace = luaL_checkstring(L, 2);
	const char* set = luaL_checkstring(L, 3);
	const char* keyString = luaL_checkstring(L, 4);
	const int numBins = lua_tointeger(L, 5);

	as_operations ops = add_bins_to_increment(L, 6, numBins);

	as_key key;
	as_key_init(&key, nameSpace, set, keyString);
	// Apply the operations. Since the record does not exist, it will be created
	// and the bins initialized with the ops' integer values.
	aerospike_key_operate(as, &err, NULL, &key, &ops, NULL);

	as_operations_destroy(&ops);
	as_key_destroy(&key);

	lua_pushnumber(L, err.code);
	lua_pushstring(L, err.message);
	return 2;
}

static const struct luaL_Reg as_client [] = {
		{"connect", connect},
		{"disconnect", disconnect},
		{"get", get},
		{"put", put},
		{"increment", increment},
		{NULL, NULL}
};

extern int luaopen_as_lua(lua_State *L){
	luaL_register(L, "as_lua", as_client);
	return 0;
}

int main()
{
	printf("testing working");

        // Initialize monitor.
        as_monitor_init(&monitor);
        as_monitor_begin(&monitor);


	 if (as_event_create_loops(1)) {
             printf("checkingevent\n");
        } else {
		printf("checking1234event\n");   
	}


        lua_State* L=lua_open();           // create a Lua state
        luaL_openlibs(L);                  // load standard libs 

	lua_State* L1=lua_open();           // create a Lua state
        luaL_openlibs(L1);  

	lua_pushstring(L, "10.254.41.200");
        lua_pushstring(L, "3000"); 
	
	connect(L);

	lua_pushlightuserdata(L1, &as);
	lua_pushstring(L1, "apiproxy");
	lua_pushstring(L1, "sso_token");
	lua_pushstring(L1, "peter016");
//        lua_pushstring(L1, "1");	

	get(L1);
	
	printf("\n\ncccc\n\n");	
//	put(L1);
	printf("\nEEEE\n");
//	as_monitor_wait(&monitor);
	get(L1);
	return 0;
}
