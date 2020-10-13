#!/bin/sh

# Script to simulate a transient error code with Retry-After header set.
#
# PATH_INFO must be of the form /<nonce>/<times>/<code>/<retry-after>/<path>
#   (eg: /dc724af1/3/429/10/some/url)
#
# The <nonce> value uniquely identifies the URL, since we're simulating
# a stateful operation using a stateless protocol, we need a way to "namespace"
# URLs so that they don't step on each other.
#
# The first <times> times this endpoint is called, it will return the given
# status <code>, and if the <retry-after> is non-negative, it will set the
# Retry-After header to that value.
#
# Subsequent calls will return a 302 redirect to <path>.
#
# Supported status codes are 429, 502, 503, and 504

print_status () {
	case $1 in
	302)
		echo "Status: 302 Found"
		;;
	429)
		echo "Status: 429 Too Many Requests"
		;;
	502)
		echo "Status: 502 Bad Gateway"
		;;
	503)
		echo "Status: 503 Service Unavailable"
		;;
	504)
		echo "Status: 504 Gateway Timeout"
		;;
	*)
		echo "Status: 500 Internal Server Error"
	esac

	echo "Content-Type: text/plain"
}

# discard leading '/' and split path into components
path=${PATH_INFO#*/}

nonce=${path%%/*}
path=${path#*/}

times=${path%%/*}
path=${path#*/}

code=${path%%/*}
path=${path#*/}

retry=${path%%/*}
path=${path#*/}

# remove trailing '/'
path="/"${path%%/}

# leave a cookie for this request/retry count
state_file="request_${REMOTE_ADDR}_${nonce}_${times}_${code}_${retry}"

if test ! -f "$state_file"
then
	echo 0 >"$state_file"
fi

read -r cnt < "$state_file"
if test "$cnt" -lt "$times"
then
	echo $((cnt+1)) >"$state_file"

	# return error
	print_status "$code"
	if test "$retry" -ge "0"
    then
		echo "Retry-After: ${retry}"
	fi
else
	# redirect
	print_status 302
	echo "Location: ${path}?${QUERY_STRING}"
fi

echo
