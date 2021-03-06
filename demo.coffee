Base58 = miniLockLib.Base58
defer = (amount, f) -> setTimeout(f, amount)
window.keys = characters.Alice


$(document).ready (event) ->
  $("#decrypt_keys").html templates["decrypt_keys"](
    aliceKeyHTML: renderByteStream characters.Alice.secretKey
    bobbyKeyHTML: renderByteStream characters.Bobby.secretKey
    sarahKeyHTML: renderByteStream characters.Sarah.secretKey
  )
  makeMiniLockFileAndDecrypt (error) ->
    console.error(error) if error
    window.scroll(1, 1)
    window.scroll(0, 0)
    $(location.hash).get(0).scrollIntoView() if location.hash
    $(document.body).removeClass("loading").addClass("ready")
    $(document).on "scroll", ->
      hash = switch
        when window.scrollY >= $('#encrypt_time').offset().top then '#encrypt_time'
        when window.scrollY >= $('#media_type').offset().top then '#media_type'
        when window.scrollY >= $('#file_name').offset().top then '#file_name'
        when window.scrollY >= $('#the_first_chunk').offset().top then '#the_first_chunk'
        when window.scrollY >= $('#ciphertext').offset().top then '#ciphertext'
        when window.scrollY >= $('#decrypt_a_permit').offset().top then '#decrypt_a_permit'
        when window.scrollY >= $('#decoding_the_header').offset().top then '#decoding_the_header'
        when window.scrollY >= $('#header').offset().top then '#header'
        when window.scrollY >= $('#size_of_header').offset().top then '#size_of_header'
        when window.scrollY >= $('#magic_bytes').offset().top then '#magic_bytes'
        else ""
      if location.hash isnt hash
        [baseUrl] = location.toString().split("#")
        history.replaceState({}, "", "#{baseUrl}#{hash}")
      if location.hash
        window.hashOffset = window.scrollY - $(location.hash).offset().top
      else
        window.hashOffset = 0
      extendArrow = if ($('#input_files').offset().top - $('#magic_bytes').offset().top) < -30 then yes else no
      $('#input_files > img.arrow').toggleClass("extended", extendArrow)

$(document).on "input", "#input_files textarea, #input_files input[type=text]", (event) ->
  makeMiniLockFileAndDecrypt.debounced (error) ->
    console.error(error) if error

$(document).on "change", "#input_files select, #input_files input[type=checkbox]", (event) ->
  makeMiniLockFileAndDecrypt (error) ->
    console.error(error) if error

$(document).on "mousedown", "a.secret_key", (event) ->
  name = $(event.currentTarget).data('name')
  if window.keys.name isnt name
    window.keys = window.characters[name]
    $('a.secret_key').removeClass("selected")
    $(event.currentTarget).addClass("selected")
    decryptMiniLockFile undefined, keys, (error) ->
      $(event.currentTarget).toggleClass("fits", error is undefined)
      $(event.currentTarget).toggleClass("jams", error?)
      console.error(error) if error


makeMiniLockFileAndDecrypt = (done) ->
  $('a.secret_key').removeClass("fits jams")
  $('#decrypt_status > div:first-child').addClass('expired')
  async.waterfall [
    (ƒ) -> makeMiniLockFile(ƒ)
    (file, ƒ) -> decryptMiniLockFile(file, undefined, ƒ)
  ], (error) ->
    $("a.secret_key.selected").toggleClass("fits", error is undefined)
    $("a.secret_key.selected").toggleClass("jams", error?)
    done(error)

makeMiniLockFileAndDecrypt.debounced = _.debounce(makeMiniLockFileAndDecrypt, 500)

makeMiniLockFile = (callback) ->
  miniLockIDs = $('input[name=minilock_ids]:checked').map((i, el) -> el.value).toArray()
  miniLockIDs.push($('input[name=minilock_ids][type=text]').val()) if $('input[name=encrypt_for_my_minilock_id]:checked').size()
  miniLockLib.encrypt
    version: 2
    data: new Blob([$("textarea").val()])
    name:  $('input[name=unencrypted_name]').val()
    keys: window.characters[$('select').val()]
    type: "text/plain"
    miniLockIDs: miniLockIDs
    callback: (error, encrypted) ->
      if encrypted
        callback(error, encrypted.data)
      else
        console.error("makeMiniLockFile", "Error making encrypted file!")
        callback(error)

decryptMiniLockFile = (file, keys, callback) ->
  $('#decrypt_status > div:first-child').addClass('expired')
  offset = window.hashOffset
  window.miniLockFile = file if file
  window.keys = keys if keys
  file = window.miniLockFile
  keys = window.keys
  operation = new miniLockLib.DecryptOperation
    data: file
    keys: keys
  operation.start (error, decrypted, header, sizeOfHeader) ->
    renderDecryptedFile(operation, decrypted, header, sizeOfHeader)
    if location.hash
      window.scroll(0, $(location.hash).offset().top + offset)
    renderMarginBytesForEachSection operation, sizeOfHeader, ->
      callback(error)

renderDecryptedFile = (operation, decrypted, header, sizeOfHeader) ->
  renderIntroduction(operation, decrypted, header, sizeOfHeader)
  renderDecryptStatus(operation, decrypted)
  renderMagicBytes(operation)
  renderSizeOfHeader(sizeOfHeader)
  renderHeader(decrypted, header, sizeOfHeader)
  renderCiphertext(operation, decrypted, header, sizeOfHeader)
  renderScrollGraph(operation, sizeOfHeader)
  renderSectionSizeGraphic(operation, sizeOfHeader)


renderIntroduction = (operation, decrypted, header, sizeOfHeader) ->
  if header?.decryptInfo
    encryptedPermits = for encodedNonce, encodedEncryptedPermit of header.decryptInfo
      nonce: miniLockLib.NACL.util.decodeBase64(encodedNonce)
      nonceHTML: renderByteStream miniLockLib.NACL.util.decodeBase64(encodedNonce)
      encoded: encodedEncryptedPermit
      encrypted: miniLockLib.NACL.util.decodeBase64(encodedEncryptedPermit)
  else
    encryptedPermits = []

  $('#unencrypted_summary').html templates["unencrypted_summary"](
    miniLockFileName: $('div.encrypted.input.file input[type=text]').val()
    miniLockFileSize: operation.data.size
    magicBytesHTML: renderByteStream [109,105,110,105,76,111,99,107]
    sizeOfHeaderBytesHTML: renderByteStream numberToByteArray(sizeOfHeader)
    sizeOfHeader: sizeOfHeader
    sizeOfCiphertext: operation.data.size - 8 - 4 - sizeOfHeader
    version: header.version
    ephemeralKeyHTML: renderByteStream miniLockLib.NACL.util.decodeBase64(header.ephemeral)
    encryptedPermits: encryptedPermits
  )
  $('#introduction_minilock_filename').html($('div.encrypted.input.file input[type=text]').val())
  $('#decrypt_summary').toggleClass("empty", decrypted is undefined)
  $("#summary_of_decrypted_ciphertext").html templates["summary_of_decrypted_ciphertext"](
    name: decrypted?.name
    type: decrypted?.type
    time: decrypted?.time
    data: if decrypted? then $("div.unencrypted.input.file textarea").val() else undefined
  )
  $("#summary_of_decrypted_header").html templates["summary_of_decrypted_header"](
    authorName: (characters.find(decrypted.senderID).name if decrypted?)
    headerSenderID: decrypted?.senderID
    headerFileKeyHTML: (renderByteStream decrypted.fileKey if decrypted?)
    headerFileNonceHTML: (renderByteStream decrypted.fileNonce if decrypted?)
    headerFileHashHTML: (renderByteStream decrypted.fileHash if decrypted?)
  )

renderDecryptStatus = (operation, decrypted) ->
  $('#decrypt_status').toggleClass("ok", decrypted?)
  $('#decrypt_status').toggleClass("failed", not decrypted?)
  template = if decrypted? then "decrypt_status_ok" else "decrypt_status_failed"
  $('#decrypt_status').append templates[template](name: operation.keys.name)
  $('#decrypt_status > div:first-child').addClass("outgoing")
  defer 250, -> $('#decrypt_status > div:first-child').remove()

renderMagicBytes = (operation) ->
  bytesAsArray = [109,105,110,105,76,111,99,107]
  $('#magic_bytes_in_base10').html(JSON.stringify(bytesAsArray))
  $('#utf8_encoded_magic_bytes').html(miniLockLib.NACL.util.encodeUTF8(bytesAsArray))
  bytesAsBase16 = ("0x#{byte.toString(16)}" for byte in bytesAsArray)
  $('#magic_bytes_in_base16').html("["+bytesAsBase16.join(",")+"]")


renderSizeOfHeader = (sizeOfHeader) ->
  $('#size_of_header_bytes').html(sizeOfHeader)


renderHeader = (decrypted, header, sizeOfHeader) ->
  $('#header_section span.keyholder').html(window.keys.name)
  $('#end_of_header_bytes').html(12+sizeOfHeader)
  $('#end_slot_of_header_bytes').html("slot #{12+sizeOfHeader}")
  $('#parsed_header').html templates["parsed_header"](
    version: header.version
    ephemeral: header.ephemeral
    decryptInfo: JSON.stringify(header.decryptInfo, undefined, 2)
  )
  ephemeralKey = miniLockLib.NACL.util.decodeBase64(header.ephemeral)
  ephemeralArray = (byte for byte in ephemeralKey)
  $('#decoded_ephemeral_key').html(renderByteStream ephemeralArray)
  $('#encoded_ephemeral_key').html(JSON.stringify(header.ephemeral))

  $("#number_of_permits").html(Object.keys(header.decryptInfo).length)

  # $('#unique_nonce').html(renderByteStream uniqueNonce)

  permitForRender = """
    senderID:    #{if decrypted? then '"'+decrypted.senderID+'"' else ''}
    recipientID: #{if decrypted? then '"'+decrypted.recipientID+'"' else ''}
    fileInfo:
      fileKey:   #{if decrypted? then '"'+miniLockLib.NACL.util.encodeBase64(decrypted.fileKey)+'"' else ''}
      fileNonce: #{if decrypted? then '"'+miniLockLib.NACL.util.encodeBase64(decrypted.fileNonce)+'"' else ''}
      fileHash:  #{if decrypted? then '"'+miniLockLib.NACL.util.encodeBase64(decrypted.fileHash)+'"' else ''}
  """
  $('#permit_with_encoded_file_info').html(permitForRender)

  permitForRender = """
    fileKey:   #{if decrypted? then renderByteStream decrypted.fileKey else ''}
    fileNonce: #{if decrypted? then renderByteStream decrypted.fileNonce else ''}
    fileHash:  #{if decrypted? then renderByteStream decrypted.fileHash else ''}
  """
  $('#permit').html(permitForRender)


renderCiphertext = (operation, decrypted, header, sizeOfHeader) ->
  $('#ciphertext_section span.keyholder').html(window.keys.name)
  if decrypted
    $('#ciphertext_section span.ok').show()
    $('#ciphertext_section span.failed').hide()
  else
    $('#ciphertext_section span.ok').hide()
    $('#ciphertext_section span.failed').show()
  $('#start_of_ciphertext').html("slot #{8 + 4 + sizeOfHeader}")
  $('#end_of_ciphertext').html("slot #{operation.data.size - 1}")
  $('#ciphertext_file_size_in_bytes').html(operation.data.size)
  $('#ciphertext_header_size_in_bytes').html(sizeOfHeader)
  $('#start_of_ciphertext_for_first_chunk').html(8 + 4 + sizeOfHeader)
  $('#decrypted_time').html decrypted?.time
  $('#decrypted_type').html decrypted?.type
  $('#decrypted_name').html decrypted?.name
  $('#ciphertext_size_in_bytes').html(operation.data.size - 8 - 4 - sizeOfHeader)
  $('#ciphertext_file_key'     ).html(if decrypted? then renderByteStream decrypted.fileKey else '')
  $('#ciphertext_file_nonce'   ).html(if decrypted? then renderByteStream decrypted.fileNonce else '')
  $('#start_of_name_bytes'     ).html(8 + 4 + sizeOfHeader)
  $('#end_of_name_bytes'       ).html(8 + 4 + sizeOfHeader + 256)
  $('#start_of_mime_type_bytes').html(8 + 4 + sizeOfHeader + 256)
  $('#end_of_mime_type_bytes'  ).html(8 + 4 + sizeOfHeader + 256 + 128)
  $('#start_of_time_bytes'     ).html(8 + 4 + sizeOfHeader + 256 + 128)
  $('#end_of_time_bytes'       ).html(8 + 4 + sizeOfHeader + 256 + 128 + 24)


renderScrollGraph = ->
  windowHeight = $(window).height()
  bodyHeight = $('body').height()
  scale = (n) -> (n / bodyHeight) * windowHeight
  magicBytesHeight = $('#magic_bytes_section').height()
  sizeOfHeaderHeight = $('#size_of_header_section').height()
  headerHeight = $('#header_section').height()
  ciphertextHeight = $('#ciphertext_section').height()
  introductionHeight = bodyHeight - magicBytesHeight - sizeOfHeaderHeight - headerHeight - ciphertextHeight
  container = $('#scrollgraph')
  container.find('.introduction').css(height: scale(introductionHeight))
  container.find('.magic').css(height: scale(magicBytesHeight))
  container.find('.size_of_header').css(height: scale(sizeOfHeaderHeight))
  container.find('.header').css(height: scale(headerHeight))
  container.find('.ciphertext').css(height: scale(ciphertextHeight))

renderSectionSizeGraphic = (operation, sizeOfHeader) ->
  scale = (n) -> (n / operation.data.size) * $(window).height()
  headerStartsAt = 12
  headerEndsAt = 12 + sizeOfHeader
  cyphertextStartsAt = headerEndsAt
  container = $('#section_sizes_graphic')
  container.find('.magic').css(height: scale(8))
  container.find('.size_of_header').css(height: scale(4))
  container.find('.header').css(height: scale(sizeOfHeader))
  container.find('.ciphertext').css(height: scale(operation.data.size - cyphertextStartsAt))

renderMarginBytesForEachSection = (operation, sizeOfHeader, done) ->
  async.series [
    (f) -> renderMarginBytes "#magic_bytes_section", operation, 0, 8, f
    (f) -> renderMarginBytes "#size_of_header_section", operation, 8, 12, f
    (f) -> renderMarginBytes "#header_section", operation, 12, 12+sizeOfHeader, f
    (f) -> renderMarginBytes "#ciphertext_section", operation, 12+sizeOfHeader, operation.data.size, f
  ], done

renderMarginBytes = (section, operation, start, end, done) ->
  operation.readSliceOfData start, end, (error, sliceOfBytes) ->
    totalBytes = end - start
    maxBytes = Math.round($(section).height() / 30)
    tags = []
    if totalBytes > maxBytes
      snipHeight = ($(section).height()-2) % 30
      stopAt = if snipHeight+10 > 30 then maxBytes-4 else maxBytes-3
      for byte, index in sliceOfBytes.subarray(0,stopAt)
        tags.push templates["margin_byte"](
          index: ((start + index) / 10000).toFixed(4).replace("0.", "")
          base10: byte.toString(10)
          base16: "0x#{byte.toString(16)}"
        )
      tags.push """<div class="snip" style="margin: -5px 0px -4px; height:#{snipHeight+10}px"><label style="display:none;">SNIPPED #{totalBytes-maxBytes} BYTES</label></div>"""
      for byte, index in sliceOfBytes.subarray(totalBytes - 3,totalBytes)
        tags.push templates["margin_byte"](
          index: ((start + index + totalBytes - 3) / 10000).toFixed(4).replace("0.", "")
          base10: byte.toString(10)
          base16: "0x#{byte.toString(16)}"
        )
    else
      for byte, index in sliceOfBytes
        tags.push templates["margin_byte"](
          index: ((start + index) / 10000).toFixed(4).replace("0.", "")
          base10: byte.toString(10)
          base16: "0x#{byte.toString(16)}"
        )
    $(section).find('div.margin_bytes').html(tags.join(""))
    done(error)

renderByteStream = (u8intArray) ->
  bytes = ('<b class="byte" title="0x'+byte.toString(16)+'" style="background-color:rgb('+byte+','+byte+','+byte+');"></b>' for byte in u8intArray)
  '<span class="byte_stream">['+bytes.join("")+']</span>'+'<span class="byte_stream_size">'+bytes.length+'</span>'


numberToByteArray = (n) ->
  byteArray = new Uint8Array(4)
  for index in [0..4]
    byteArray[index] = n & 255
    n = n >> 8
  byteArray
