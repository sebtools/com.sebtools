component display="Rate Governor" extends="mxunit.framework.TestCase" {

	public function beforeTests() {
		// Any needed set up code can go here.
	}

	// Test that RateGovernor will run a method immediately if no other methods had been run.
	public function shouldRunImmediately() hint="Method should run immediately if no other method has run yet." {
		var oRateGovernor = createRateGovernor(
			id = "TestRG:#CreateUUID()#",
			interval = "1 minute",
			limit = 5
		);
		var before = now();

		oRateGovernor.addToQueue(
			args = { when=before }
		);

		assertTrue(hasRunSince(before), "The method did not run immediately.");

	}

	// Test that RateGovernor will run a method immediately if no other methods had been run.
	public function shouldRunImmediatelyWithCallBack() hint="Method should run immediately with a callback if no other method has run yet." {
		var oRateGovernor = createRateGovernor(
			id = "TestRG:#CreateUUID()#",
			interval = "1 minute",
			limit = 5
		);
		var before = now();

		oRateGovernor.addToQueue(
			args = { when=before },
			callback = function() {return 1;}
		);

		assertTrue(hasRunSince(before), "The method did not run immediately.");

	}

	// Test that RateGovernor will run a method immediately if no other methods had been run.
	public function shouldRunToLimit() hint="RateGovernor should run up to the limit." {
		var limit = 2;
		var oRateGovernor = createRateGovernor(
			id = "TestRG:#CreateUUID()#",
			interval = "1 minute",
			limit = limit
		);
		
		Variables.RunCount = 0;

		oRateGovernor.addToQueue(
			args = { r=1 }
		);
		oRateGovernor.addToQueue(
			args = { r=2 }
		);
		oRateGovernor.addToQueue(
			args = { r=3 }
		);

		assertEquals(limit,Variables.RunCount, "The method did not run a number of times equal to the limit.");

	}

	// Test that RateGovernor will run a method immediately if no other methods had been run.
	public function shouldProcessQueue() hint="RateGovernor should properly handle subsequent calls to processing." {
		var limit = 2;
		var seconds = 3;
		var numItems = 6;
		var oRateGovernor = createRateGovernor(
			id = "TestRG:#CreateUUID()#",
			interval = "#seconds# seconds",
			limit = limit
		);
		
		Variables.RunCount = 0;

		// Add 6 items to the queue
		// The first 2 should run immediately, the next 4 should be queued.
		for ( ii=1; ii <= numItems; ii++ ) {
			oRateGovernor.addToQueue( args={ r=ii } );
		}

		assertEquals(limit,Variables.RunCount, "The method did not run a number of times equal to the limit.");

		// Process the queue without waiting for the interval to expire.
		oRateGovernor.processQueue();

		assertEquals(limit,Variables.RunCount, "RateGoverober did not wait for the time to run.");

		// Wait for the interval to expire and process the queue again.
		sleep( seconds * 1000);
		oRateGovernor.processQueue();

		assertEquals( (limit*2) ,Variables.RunCount, "RateGovernor did not process the correct number after waiting an interval.");
		
		// Process the queue without waiting for the interval to expire.
		oRateGovernor.processQueue();

		assertEquals( (limit*2) ,Variables.RunCount, "RateGovernor did not wait for the time to run.");

		// Wait for the interval to expire and process the queue again.
		sleep( seconds * 1000);
		oRateGovernor.processQueue();

		assertEquals( (limit*3) ,Variables.RunCount, "RateGovernor did not process the correct number after waiting an interval.");

		// Wait for the interval to expire and process the queue again.
		sleep( seconds * 1000);
		oRateGovernor.processQueue();

		assertEquals( numItems ,Variables.RunCount, "RateGovernor did not process all of the queue.");

	}

	private function hasRunSince(required date when) {
		return (
			StructKeyExists(Variables, "LastRun")
			AND
			Variables.LastRun GTE Arguments.when
		);
	}

	public function runMethod() {

		Variables.RunCount = StructKeyExists(Variables,"RunCount") ? Variables.RunCount + 1 : 1;
		
		Variables.LastRun = now();

	}

	private function createRateGovernor(
		required string id,
		required string interval,
		required numeric limit,

		string IdempotentKey
	) {
		var oDataMgr = CreateObject("component", "com.sebtools.DataMgr").init(datasource="TestSQL");
		var oScheduler = CreateObject("component", "com.sebtools.Scheduler").init(
			oDataMgr,
			"TestRateGovernor",
			"testMethod",
			"testKey"
		);
		var sArgs = {
			"Scheduler" = oScheduler,
			"id" = Arguments.id,
			"Service" = This,
			"MethodName" = "runMethod",
			"interval" = Arguments.interval,
			"limit" = Arguments.limit
		};
		if (  StructKeyExists(Arguments, "IdempotentKey")) {
			sArgs["IdempotentKey"] = Arguments.IdempotentKey;
		}

		return CreateObject("component", "com.sebtools.RateGovernor").init(
			ArgumentCollection=sArgs
		);
	}
}