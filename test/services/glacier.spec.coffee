helpers = require('../helpers')
AWS = helpers.AWS
Buffer = AWS.util.Buffer

if AWS.util.isNode()
  describe 'AWS.Glacier', ->

    glacier = null
    agentHeader = null
    if AWS.util.isBrowser()
      agentHeader = 'X-Amz-User-Agent'
    else
      agentHeader = 'User-Agent'

    beforeEach ->
      glacier = new AWS.Glacier()

    describe 'building requests', ->
      it 'sets accountId to "-" if not set', ->
        req = glacier.listVaults()
        req.emit('validate', [req])
        req.emit('build', [req])
        expect(req.httpRequest.path).to.equal('/-/vaults')

      it 'will not override accountId if set', ->
        req = glacier.listVaults(accountId: 'ABC123')
        req.emit('validate', [req])
        req.emit('build', [req])
        expect(req.httpRequest.path).to.equal('/ABC123/vaults')

      it 'computes the SHA 256 checksum header only once', ->
        spy = helpers.spyOn(AWS.util.crypto, 'sha256').andCallThrough()
        # Compute checksum of <= 1 megabyte buffer
        # This will invoke AWS.util.crypto.sha256() only once
        req = glacier.uploadArchive(vaultName: 'foo', body: 'bar')
        req.removeAllListeners('sign')
        req.build()
        expect(spy.calls.length).to.eql(1)

      it 'adds linear and tree hash headers to payload requests', ->
        headers =
          'x-amz-glacier-version': '2012-06-01'
          'X-Amz-Content-Sha256': 'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9'
          'x-amz-sha256-tree-hash': 'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9'
          'Content-Length': 3
          Host: 'glacier.mock-region.amazonaws.com'
        headers[agentHeader] = AWS.util.userAgent()
        req = glacier.uploadArchive(vaultName: 'foo', body: 'bar')
        req.removeAllListeners('sign')
        req.build()
        expect(req.httpRequest.headers).to.eql(headers)

    describe 'computeChecksums', ->
      it 'returns correct linear and tree hash for buffer data', ->
        # compute a 5.5 megabyte chunk of data filled with '0' string (0 byte)
        # expected values taken from AWS SDK for Ruby
        data = new Buffer(1024 * 1024 * 5.5)
        data.fill('0')

        expected =
          linearHash: '68aff0c5a91aa0491752bfb96e3fef33eb74953804f6a2f7b708d5bcefa8ff6b',
          treeHash: '154e26c78fd74d0c2c9b3cc4644191619dc4f2cd539ae2a74d5fd07957a3ee6a'

        expect(glacier.computeChecksums(data)).to.eql(expected)

    describe 'initiateJob', ->
      it 'correctly builds the request', ->
        helpers.mockHttpResponse 200, {}, ''
        params =
          vaultName: 'vault-name'
          jobParameters:
            Format: 'foo'
            Type: 'bar'
        glacier.initiateJob params, (err, data) ->
          req = this.request.httpRequest
          expect(req.path).to.equal('/-/vaults/vault-name/jobs')
          expect(req.body).to.equal('{"Format":"foo","Type":"bar"}')

    describe 'uploadArchive', ->
      it 'passes the body along', ->
        helpers.mockHttpResponse 200, {}, ''
        params =
          vaultName: 'vault-name'
          body: 'abc'
        glacier.uploadArchive params, (err, data) ->
          req = this.request.httpRequest
          expect(req.method).to.equal('POST')
          expect(req.path).to.equal('/-/vaults/vault-name/archives')
          expect(req.body).to.equal('abc')
