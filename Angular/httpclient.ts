/**
 * Created by vikram.chirumamilla on 6/20/2017.
 */

import { Injectable } from '@angular/core';
import { ConnectionBackend, RequestOptions, Request, RequestOptionsArgs, Response, Http, Headers } from '@angular/http';

import { environment } from 'environments/environment';
import { Observable } from 'rxjs/Rx';
import { get } from 'lodash';

@Injectable()
export class HttpClient extends Http {

  constructor(backend: ConnectionBackend, defaultOptions: RequestOptions) {
    super(backend, defaultOptions);
  }

  public request(url: string | Request, options?: RequestOptionsArgs): Observable<Response> {
    return super.request(url, options);
  }

  public get(url: string, params?: URLSearchParams): Observable<Response> {
    url = this.getAbsoluteUrl(url);
    const options = this.getRequestOptionArgs();
    if (params != null) {
      options.params = params;
    }

    return super.get(url, options);
  }

  public post(url: string, body: string, options?: RequestOptionsArgs): Observable<Response> {
    url = this.getAbsoluteUrl(url);
    return super.post(url, body, this.getRequestOptionArgs(options));
  }

  public put(url: string, body: string, options?: RequestOptionsArgs): Observable<Response> {
    url = this.getAbsoluteUrl(url);
    return super.put(url, body, this.getRequestOptionArgs(options));
  }

  public delete(url: string, options?: RequestOptionsArgs): Observable<Response> {
    url = this.getAbsoluteUrl(url);
    return super.delete(url, this.getRequestOptionArgs(options));
  }

  private getAbsoluteUrl(relativePath: string) {
    return  environment.Api_Url + relativePath;
  }

  private getRequestOptionArgs(options?: RequestOptionsArgs): RequestOptionsArgs {

    if (options == null) {
      options = new RequestOptions();
    }

    if (options.headers == null) {
      options.headers = new Headers();
    }

    if (!options.headers.has('Content-Type')) {
      options.headers.append('Content-Type', 'application/json');
    }
    options.headers.append('Ocp-Apim-Subscription-Key', environment.Api_Token);
    options.headers.append('bearer', 'token');
    return options;
  }

  handleHttpError(error: Response | any) {
    // In a real world app, you might use a remote logging infrastructure
    let errMsg: string;
    if (error instanceof Response) {
      const body = error.json() || '';
      const err = get(body, 'error', JSON.stringify(body));
      errMsg = `${error.status} - ${error.statusText || ''} ${err}`;
    } else {
      errMsg = error.message ? error.message : error.toString();
    }
    console.error(errMsg);
    return Observable.throw(errMsg);
  }

}
