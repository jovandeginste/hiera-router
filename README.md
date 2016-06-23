# Hiera 'router' backend

This hiera backend replaces the default yaml backend, but will resend queries to other hiera backends based on the value returned by the yaml files.

When hiera-router gets a string matching `BACKEND[otherbackendname]`, it will resend the same query to `otherbackendname`.

Documentation has to be expanded a lot, but the gist is here.

*Big caveat:* you can use every class of backend only once (so only one hiera-vault, one hiera-http, etc). We have a plan for this, but this has not yet been implemented.

## Example

Content of `./hiera.yaml`:

```yaml
:backends:
  - router
:logger: console
:hierarchy:
  - level1
  - level2
:router:
  :datadir: ./hieradata/
  :backends:
    - vault
:vault:
  :ssl_verify: false
  :addr: https://active.vault.service.consul:8200
  :token: mytoken
  :mounts:
    :generic:
      - secret/puppet
```

Content of `./hieradata/level1.yaml`:

```yaml
mykey: backend[vault]
mykey2: backend[vault]
```

Content of `./hieradata/level2.yaml`:

```yaml
mykey:
  hiera-value: 25
  other-hiera-value: xyz
mykey2: some_value
```

And a `vault` server setup so that `mytoken` has read access to `secret/puppet`, and contains a key
`secret/puppet/level1/mykey` with values:

```yaml
vault-value: a
other-vault-value: 2
```

This example will find 'look in vaul' value in `level1.yaml`, try to look in vault, will return empty handed and thus
look further in the yaml tree and find `some_value` in `level2.yaml`:

```
$ hiera -c hiera.yaml mykey2
some_value
```

Request a string, so no merging will happen. First value found is 'look in vault', which has a value for this key:

```
$ hiera -c hiera.yaml mykey
{"vault-value"=>"a", "other-vault-value"=>"2"}
```

Request a hash, so merging will happen. First value found is 'look in vault', which has a value for this key. Another set of values is found in `level2.yaml`, which are added:

```
$ hiera -c hiera.yaml -h mykey # Request a hash, so merging will happen
{"hiera-value"=>25, "other-hiera-value"=>"xyz", "vault-value"=>"a", "other-vault-value"=>"2"}
```

In Ruby code:

```ruby
require 'hiera'
backend = Hiera.new(:config => 'hiera.yaml')

puts backend.lookup("mykey", "mydefault", {}, nil, :string).inspect
# result: {"vault-value"=>"a", "other-vault-value"=>"2"}

puts backend.lookup("mykey", "mydefault", {}, nil, :hash).inspect
# result: {"hiera-value"=>25, "other-hiera-value"=>"xyz", "vault-value"=>"a", "other-vault-value"=>"2"}

puts backend.lookup("mykey2", "mydefault", {}, nil, :string).inspect
# result: "some_value"
```
