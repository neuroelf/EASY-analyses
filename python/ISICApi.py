#!/usr/bin/env python
# -*- coding: utf-8 -*-

###############################################################################
#  Copyright Kitware Inc.
#
#  Licensed under the Apache License, Version 2.0 ( the "License" );
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
###############################################################################

import requests
import getpass
import json

class ISICApi(object):

    BASEURL = 'https://isic-archive.com'

    def __init__(self, hostname=None, username=None, password=None):
        if hostname is None:
            hostname = self.BASEURL
        self.baseUrl = '%s/api/v1' % hostname
        self.authToken = None

        if username is not None:
            if password is None:
                password = getpass.getpass('Password for user "%s":' % username)
            self.authToken = self._login(username, password)

    def _makeUrl(self, endpoint):
        return '%s/%s' % (self.baseUrl, endpoint)

    def _login(self, username, password):
        authResponse = requests.get(
            self._makeUrl('user/authentication'),
            auth=(username, password)
        )
        if not authResponse.ok:
            raise Exception('Login error: %s' % authResponse.json()['message'])

        authToken = authResponse.json()['authToken']['token']
        return authToken

    def get(self, endpoint):
        url = self._makeUrl(endpoint)
        headers = {'Girder-Token': self.authToken} if self.authToken else None
        return requests.get(url, headers=headers)

    def getFile(self, endpoint, storeas=None):
        if storeas is None:
            return self.get(endpoint)
        url = self._makeUrl(endpoint)
        headers = {'Girder-Token': self.authToken} if self.authToken else None
        r = requests.get(url, headers=headers, allow_redirects=True)
        open(storeas, 'wb').write(r.content)

    def getJson(self, endpoint):
        return self.get(endpoint).json()

    def getJsonList(self, endpoint):
        #endpoint += '&' if '?' in endpoint else '?'
        #endpoint += 'limit=10000'
        resp = self.get(endpoint).json()
        for item in resp:
            yield(item)
    
    def getEndpoint(self, endpoint='study', endpointId=None):
        endpoint = '/' + endpoint
        if endpointId is None:
            try:
                output = self.getJsonList(endpoint)
                while True:
                    yield next(output)
            except StopIteration:
                pass
            finally:
                del output
        else:
            return self.getJson(endpoint)

    def getStudy(self, studyId=None):
        if studyId is None:
            try:
                studyList = self.getJsonList('study')
                studyId = next(studyList)
                print(studyId)
            finally:
                del studyList
            if studyId is None:
                raise(Exception('Error retrieving studies.'))
        return self.getJson('study/%s' % (studyId))
