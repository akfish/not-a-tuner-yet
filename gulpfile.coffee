path	  = require 'path'
gulp	  = require 'gulp'
gutil	  = require 'gulp-util'
coffee	= require 'gulp-coffee'
map	    = require 'gulp-sourcemaps'
less	  = require 'gulp-less'
jade	  = require 'gulp-jade'
rimraf	= require 'gulp-rimraf'
run	    = require 'gulp-run'
connect = require 'gulp-connect'
watch	  = require 'gulp-watch'
data	  = require 'gulp-data'
ignore  = require 'gulp-ignore'

publish_root   = './publish/'
module_root    = './modules/'

modules = []#['seajs-preload']

# Config
config = require './config'

# Sources
coffee_src    = './coffee/**/*.coffee'
jade_src      = './jade/**/*.jade'
less_src      = './less/**/*.less'
static_src    = './static/**/*.*'
sea_src	      = './sea-modules/**/*.*'
upstream_src  = './upstream-modules/**/*.*'

# Ignore
git_dir       = '.git/**/*.*'

publish_to = (folder) ->
	path.join publish_root, folder

copy = (from, to) ->
	gulp.src from
		.pipe ignore.exclude git_dir
		.pipe gulp.dest to

deploy_static = ->
	copy static_src, publish_root

spm_build = (callback) ->
	if not modules? or modules.length == 0
		callback()
	cmd = "spm build -O ../../sea-modules"
	for m in modules
		cwd = path.join module_root, m
		run cmd, cwd: cwd
			.exec(callback)

deploy_sea_modules = ->
	copy sea_src,      publish_to('sea-modules')
	copy upstream_src, publish_to('sea-modules')

watch_sources = ->
	gulp.watch jade_src,                ['jade']
	gulp.watch less_src,                ['less']
	gulp.watch coffee_src,              ['coffee']
	gulp.watch jade_src,                ['jade']
	gulp.watch static_src,              ['static']
	gulp.watch [sea_src, upstream_src], ['sea']

compile_jade = ->
	gulp.src jade_src
		.pipe data((f, cb) -> cb(config))
		.pipe jade()
		.on 'error', gutil.log
		.pipe gulp.dest publish_root

compile_coffee = ->
	gulp.src coffee_src
		.pipe coffee bare: true
		.on 'error', gutil.log
		.pipe gulp.dest publish_to('script')

compile_less = ->
	gulp.src less_src
		.pipe less()
		.on 'error', gutil.log
		.pipe gulp.dest publish_to('style')

clean_publish = (callback) ->
	rimraf publish_root, callback

gulp.task 'clean', (callback) ->
	console.log "Clean it your self!"
	callback()
	#clean_publish(callback)

gulp.task 'spm', (callback) ->
	spm_build(callback)

gulp.task 'jade', ->
	compile_jade()

gulp.task 'less', ->
	compile_less()

gulp.task 'coffee', ->
	compile_coffee()

gulp.task 'sea', ['spm'], ->
	deploy_sea_modules()

gulp.task 'static', ->
	deploy_static()

gulp.task 'all', ['sea', 'static', 'jade', 'less', 'coffee']

gulp.task 'server', ['all'], ->
	connect.server
		root: ['./publish']
		livereload: true

gulp.task 'watch', ->
	watch_sources()

gulp.task 'livereload', ->
	gulp.src [jade_src, coffee_src, less_src, static_src], read: false
		.pipe watch()
		.pipe connect.reload()

gulp.task 'default', ['sea', 'static', 'jade', 'less', 'coffee', 'watch', 'server', 'livereload']
