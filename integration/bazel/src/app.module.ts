import {NgModule} from '@angular/core';
import {BrowserModule} from '@angular/platform-browser';

// HttpClientModule is not used in this example yet but we import 
// from @angular/common/http to ensure that secondary endpoint imports
// work with Bazel
import {HttpClientModule} from '@angular/common/http';

import {AppComponent} from './app.component';
import {HelloWorldModule} from './hello-world/hello-world.module';

@NgModule({
  imports: [BrowserModule, HttpClientModule, HelloWorldModule],
  declarations: [AppComponent],
  bootstrap: [AppComponent],
})
export class AppModule {}
