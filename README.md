[![Gem Version](https://badge.fury.io/rb/hiera-router.svg)](https://badge.fury.io/rb/hiera-router)

# Hiera 'router' backend

This hiera backend replaces the default yaml backend, but will resend queries to other hiera backends based on the value returned by the yaml files.

When hiera-router gets a string matching `backend[otherbackendname]`, it will resend the same query to `otherbackendname`.

Documentation has to be expanded a lot, but the gist is here.

*Big caveat:* you can use every class of backend only once (so only one hiera-vault, one hiera-http, etc). We have a plan for this, but this has not yet been implemented.

# Upgrading to 0.3.0

I now support hiera v5 with v0.3.0; this meant I had to make some deep changes, and I chose to make a breaking change in the configuration. This makes it a bit more flexible at the same time..

Basically, replace the following style:

```yaml
:router:
  :backends:
    - vault
  :vault:
    :backend_class: mock
```

With this one:

```yaml
:router:
  :backends:
    :vault:
      :backend_class: mock
```

`vault` and `mock` are two hiera backends, and in the example I tell the router to use the `mock` backend instead of the real `vault` one, eg. for integration testing purposes.

If you want the configuration used for the `mock` backend not to come from the `mock` top level key, you can specify `backend_key` too, eg.:

```yaml
:router:
  :backends:
    :vault:
      :backend_class: mock
      :backend_key: othermock
:vault:
  :ssl_verify: false
  :addr: https://active.vault.service.svcd:8200
  :mounts:
    :generic:
      - secret/puppet
:mock:
  :datafile: ./test.yaml
:othermock:
  :datafile: ./othertest.yaml
```

# Example

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
    :vault:
      :backend_class: mock
:mock:
  :datafile: ./test.yaml
:vault:
  :ssl_verify: false
  :addr: https://active.vault.service.svcd:8200
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
