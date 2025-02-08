#include <stdio.h>
#include <stdlib.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

void call_lua_script(lua_State *L, char *script_path, int argc, char **argv) {
    luaL_openlibs(L);

    if(luaL_dofile(L, "main.lua") != LUA_OK) {
        fprintf(stderr, "Error loading script: %s\n", lua_tostring(L, -1));
        lua_close(L);
        exit(1);
    }

    lua_newtable(L);
    for (int i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "c_args");

    lua_getglobal(L, "main");
    if(lua_pcall(L, 0, 0, 0) != LUA_OK) {
        fprintf(stderr, "Error running script: %s\n", lua_tostring(L, -1));
        lua_close(L);
        exit(1);
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <path_to_lua_script> [args...]\n", argv[0]);
        return 1;
    }
    lua_State *L = luaL_newstate();
    if (L == NULL) {
        fprintf(stderr, "Cannot create state: not enough memory\n");
        return 1;
    }


    call_lua_script(L, argv[1], argc - 1, &argv[1]);
    lua_close(L);
    return 0;
}