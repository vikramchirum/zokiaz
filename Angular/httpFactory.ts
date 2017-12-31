/**
 * Created by vikram.chirumamilla on 6/20/2017.
 */
import { XHRBackend, Http, RequestOptions } from '@angular/http';
import { HttpClient } from './httpclient';

export function httpFactory(xhrBackend: XHRBackend, requestOptions: RequestOptions): Http {
  return new HttpClient(xhrBackend, requestOptions);
}
