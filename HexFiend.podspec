Pod::Spec.new do |s|
  s.name = 'HexFiend'
  s.version = '2.12b2'
  s.summary = 'A framework designed to enable applications to support viewing and editing of binary data.'
  s.homepage = 'http://ridiculousfish.com/hexfiend/docs/'
  s.authors = { 'ridiculousfish' => 'hex_fiend@ridiculousfish.com' }
  s.source = { :git => 'https://github.com/ridiculousfish/HexFiend' }

  s.osx.deployment_target = '10.9'

  s.source_files = 'framework/sources/*.{h,m}',
    'framework/sources/BTree/*.{h,m}',
    'framework/tests/*.h',
    'helper_subprocess/*.{defs,h}'

  s.exclude_files = 'framework/sources/HFTestRepresenter.*'
  s.prefix_header_file = 'framework/sources/HexFiend_2_Framework_Prefix.pch'
  s.compiler_flags = '-DMacAppStore=1', '-DHF_NO_PRIVILEGED_FILE_OPERATIONS=1'
end
