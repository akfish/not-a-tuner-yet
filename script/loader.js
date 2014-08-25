var paths;

paths = {
  "lib": "/script"
};

seajs.config({
  base: "/sea-modules/",
  paths: paths,
  alias: {
    "jquery": "jquery/2.1.1/jquery.js"
  }
});
