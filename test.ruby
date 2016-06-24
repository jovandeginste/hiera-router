#!/usr/bin/env ruby

require 'hiera'
backend = Hiera.new(:config => 'hiera.yaml')

puts backend.lookup("blub", "haha", {"::hostname"=>"icts-p-nx-4"}, nil, :hash).inspect

# result: {"hiera-value"=>25, "blobber"=>"xyz", "blub"=>"a", "tweede"=>"2"}

puts backend.lookup("blub2", "haha", {"::hostname"=>"icts-p-nx-4"}, nil, :string).inspect

# result: "something"
