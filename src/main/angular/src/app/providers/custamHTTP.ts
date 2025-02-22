
import { Injectable } from '@angular/core';
import { HttpClient, HttpResponse, HttpHeaders, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { throwError } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { BASEURL } from './app.constant';
import { Router } from '@angular/router';
import { StorageService } from './localStorage';
import { AlertService } from './alertService';
import { TostService } from './tost.service';
import { BrowserStack } from 'protractor/built/driverProviders';

/**
 * Api is a generic REST Api handler. Set your API url first.
 */
@Injectable()
export class CustomHttpService {
    url: string = BASEURL;

    constructor(public http: HttpClient, public storage: StorageService, public tost: TostService,
        // tslint:disable-next-line:align
        public router: Router, public alertService: AlertService) { }

    getHeaders(optHeaders?: HttpHeaders) {
        let headers = new HttpHeaders();
        if (this.storage.getData('access_token')) {
            headers = headers.set(
                'Authorization',
                'Bearer ' + this.storage.getData('access_token')
            );
        } else {
            headers = headers.set(
                'Authorization',
                'Basic ' + btoa('efkon-msil:nxtlife')
            );
        }
        if (optHeaders) {
            for (const optHeader of optHeaders.keys()) {
                headers = headers.append(optHeader, optHeaders.get(optHeader));
            }
        }
        return headers;
    }

    get(endpoint: string, optHeaders?: HttpHeaders) {
        const headers = this.getHeaders(optHeaders);
        return this.http
            .get(this.url + '/' + endpoint, { headers: headers, observe: 'response' })
            .pipe(map(this.extractData), catchError(this.handleError));
    }

    post(endpoint: string, body: any, optHeaders?: HttpHeaders) {
        const headers = this.getHeaders(optHeaders);
        return this.http
            .post(this.url + '/' + endpoint, body, {
                headers: headers,
                observe: 'response',
            })
            .pipe(map(this.extractData), catchError(this.handleError));

    }


    put(endpoint: string, body: any, optHeaders?: HttpHeaders) {
        const headers = this.getHeaders(optHeaders);
        return this.http
            .put(this.url + '/' + endpoint, body, {
                headers: headers,
                observe: 'response'
            }).pipe(map(this.extractData), catchError(this.handleError));

    }

    delete(endpoint: string, optHeaders?: HttpHeaders) {
        const headers = this.getHeaders(optHeaders);
        return this.http
            .delete(this.url + '/' + endpoint, {
                headers: headers,
                observe: 'response'
            })
            .pipe(map(this.extractData), catchError(this.handleError));

    }

    patch(endpoint: string, body: any, optHeaders?: HttpHeaders) {
        const headers = this.getHeaders(optHeaders);
        return this.http
            .put(this.url + '/' + endpoint, body, {
                headers: headers,
                observe: 'response'
            })
            .pipe(map(this.extractData), catchError(this.handleError));

    }

    extractData(response: HttpResponse<any>) {
        return response.body || response.status;
    }

    handleError = (errorResponse: HttpErrorResponse) => {
        switch (errorResponse.status) {
            case 401:
                this.router.navigate(['/login']).then(() => {
                    this.tost.errorAlert('invalid credentials please try again ');
                });
                this.storage.clearData();
                break;
            case 400:
                this.tost.errorAlert('invalid credentials please try again ');
                break;
            case 0:
                this.tost.errorAlert('You don\'t seem to have an active internet connection. Please connect and try again.');
                break;
            default:
                this.tost.showNotificationFailure(errorResponse.error);
                // this.alertService.errorAlert(errorResponse.error.message);
                break;
        }
        return throwError(errorResponse);
    }
}


