## Environment variables

### The `.env` file

The `.env` file holds [persisted environment variables], such as the list of enabled [dependencies].

It is automatically created on each invocation of `make` through the `.env` [target] declared in the [make/utils/env.mk] Makefile.

It can be removed either manually or with the [clean] target.

### Persisted environment variables

Persisted environment variables in the [`.env`] file are those parsed from the included Makefiles and which follows a [declaration pattern].

| Name                  | Aliases               | Description                       | Default value
|:--                    |:--                    |:--                                |:--
| `DEPENDENCIES`        | `DEPS`                | List of enabled [dependencies]    | `null`

>[!NOTE]
>[dependencies] can also define persisted environment variables like the `BIN_DIR` variable defined by the [host] dependency.

### Special variables

Special variables are **not** persisted in the [`.env`] file and can be declared through the command line, they can have any value once they are declared.

| Name                  | Aliases               | Description                       | Default value
|:--                    |:--                    |:--                                |:--
| `VERBOSE`             |                       | Enables make recipes verbosity    | `undefined`
| `NOCOLORS`            |                       | Disables colored [display]        | `undefined`

#### Example

```shell
make VERBOSE=1 NOCOLORS=yes
```

### Variables declaration patterns

Variables persisted in the [`.env`] file are those which are declared with the following assignments

| Assignment                                    | Example
|:--                                            |:--
| [conditional variable assignment]             | `FOO ?= bar`
| immediate [variable assignment]               | `FOO ::= bar`
| immediate [variable assignment] with escape   | `FOO :::= bar`
| [shell assignment operator]                   | `FOO != echo bar`

### Shell assigned variables

>[!IMPORTANT]
>Variables declared with the [shell assignment operator] or which value relies on a [shell function] **must** be declared with an immediate [variable assignment] inside of a `ifndef` [condition] for performance reasons.

#### Examples

Declaring a variable value from a [shell function] with the immediate [variable assignment] inside a
`ifndef` [condition].

```shell
ifndef OS
OS					::= $(shell uname -s | tr "[:upper:]" "[:lower:]")
endif
```

Declaring a variable with the [shell assignment operator] inside a `ifndef` [condition].

```shell
ifndef OS
OS					!= uname -s | tr "[:upper:]" "[:lower:]"
endif
```

### Extra environment files

Extra environment files follows the naming pattern `.env.*` ( e.g. : `.env.local`, `.env.override` ) and are automatically included **after** the [`.env`] file.

They are **not deleted automatically** instead of the [`.env`] file which is strongly coupled to the project lifecycle, thus making them useful for persisting user-defined variables.

#### Example usage of an extra environment file

>Given the makefile `./make/secret.mk` declaring `MY_SECRET` with the default value `secret123!` and a recipe to display its value

```shell
# ./make/secret.mk
MY_SECRET	?= secret123!

.PHONY: secret
secret:
	echo "MY_SECRET=$(MY_SECRET)"
```

>Which outputs the following line in the [`.env`] file upon invoking make

```shell
# ./.env
MY_SECRET=secret123!
```

>Adding the extra environment file `.env.secret` with the following content

```shell
# ./.env.secret
MY_SECRET=V8ryS3cr3t!
```

>Outputs the following when invoking the recipe

```shell
$ make secret
MY_SECRET=V8ryS3cr3t!
```

>[!NOTE]
>In the above example the variable `MY_SECRET` will be persisted in both the [`.env`] and `.env.secret` files.

>To avoid that behavior, especially when dealing with secrets, make the variable mandatory without a default value.

```shell
# ./make/secret.mk
ifndef MY_SECRET
$(error Variable MY_SECRET is undefined)
endif

.PHONY: secret
secret:
	echo "MY_SECRET=$(MY_SECRET)"
```

[`.env`]: #the-env-file
[persisted environment variables]: #persisted-environment-variables
[dependencies]: ./deps.md
[clean]: ./clean.md
[make/utils/env.mk]: ../make/utils/env.mk
[target]: https://www.gnu.org/software/make/manual/make.html#What-a-Rule-Looks-Like
[declaration pattern]: #variables-declaration-patterns
[conditional variable assignment]: https://www.gnu.org/software/make/manual/make.html#Conditional-Variable-Assignment
[variable assignment]: https://www.gnu.org/software/make/manual/make.html#Variable-Assignment
[shell function]: https://www.gnu.org/software/make/manual/make.html#The-shell-Function
[condition]: https://www.gnu.org/software/make/manual/make.html#Syntax-of-Conditionals
[shell assignment operator]: https://www.gnu.org/software/make/manual/make.html#Setting-Variables
[display]: ./display.md#disabling-colors
[special dependency]: ./deps.md#special-dependencies
[host]: ./deps/host.md
