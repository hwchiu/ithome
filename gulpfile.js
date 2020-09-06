const gulp = require('gulp');
const gulpLoadPlugins = require('gulp-load-plugins');
const sitemap = require('gulp-sitemap');

const $ = gulpLoadPlugins();

gulp.task('sitemap', function () {
   return gulp.src('./_book/*/**/*.html', {
            read: false
        })
        .pipe(sitemap({
            siteUrl: 'http://ithome.hwchiu.com'
        }))
        .pipe(gulp.dest('./'));
});

gulp.task('publish', () => {
  console.log('Publish Gitbook (_book) to Github Pages');
  return gulp.src('./_book/**/*')
    .pipe($.ghPages({
      origin: 'origin',
      branch: 'gh-pages'
    }));
});
