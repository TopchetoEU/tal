local loading = require "tal.compiler.loading";

package.loaders[2] = loading.mod_searcher;

_G.load = loading.load;
