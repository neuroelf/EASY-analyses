#!/usr/bin/env python
# -*- coding: utf-8 -*-

# the initial code 

import getpass
import json
import re
import requests

# helper function that returns True for valid looking mongo ObjectId strings
mongoObjectIdPattern = re.compile(r"^[0-9a-f]{24}$")
def couldBeMongoObjectId(testId:str = "") -> bool:
    return (len(testId) == 24 and (not re.match(mongoObjectIdPattern, testId) is None))

class ISICApi(object):

    BASEURL = 'https://isic-archive.com'

    def __init__(self, hostname=None, username=None, password=None):
        if hostname is None:
            hostname = self.BASEURL
        self.baseUrl = '%s/api/v1' % hostname
        self.authToken = None
        self.images = dict()
        self.studies = dict()

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

    def getImageIdByName(self, imageName: str = "") -> str:
        if imageName == '':
            raise ValueError('Image name must not be empty.')
        if imageName in self.images:
            return self.images[imageName]
        imageInfo = self.getJson('/image?details=false&name=%s' % imageName)
        if not imageInfo:
            raise KeyError('Image %s not found.' % (imageName))
        self.images[imageName] = imageInfo[0]['_id']
        return self.images[imageName]

    def getImageIdByISICNum(self, imageNum: int = -1) -> str:
        if imageNum < 0:
            raise ValueError('Requires an image number >= 0.')
        if imageNum > 9999999:
            raise ValueError('Requires an image number < 10000000')
        return self.getImageIdByName('ISIC_{0:07d}'.format(imageNum))

    def getStudy(self, studyId=None):
        if studyId is None:
            return self.getJsonList('study')
        if couldBeMongoObjectId(studyId):
            return self.getJson('study/%s' % (studyId))
        else:
            return self.getStudy(self.getStudyIdByName(studyId))
        
    def getStudyIdByName(self, studyName: str = "") -> str:
        if not self.studies:
            self.getStudies()
        if studyName == "":
            raise ValueError('Requires a study name.')
        if studyName in self.studies:
            return self.studies[studyName]
        else:
            raise KeyError('Study %s not found' % (studyName))

    def getStudies(self) -> dict:
        if not self.studies:
            studies = self.getStudy()
            for study in studies:
                self.studies[study['name']] = study['_id']
        return self.studies

    def getStudyAnnotations(self, studyNameOrId: str) -> dict:
        pass
