var partitionFunction = function (val, index, collection) {
    return index > collection.length*Math.min(0.5, Math.log(Math.E)/(0.9*Math.log(collection.length)));
};
var chisquare10 = [0.0642,0.4463,1.0025,1.6488,2.3425,3.0701,3.8223];

App = Ember.Application.create();

App.Estimation = Ember.Object.extend({
    possibleSimulationSize: [
        {name: "Funky simulation (10 simulations)", value: 10},
        {name: "Rough simulation (100 simulations)", value: 100},
        {name: "Good simulation (1000 simulations)", value: 1000},
        {name: "Precise simulation (10000 simulations)", value: 10000},
        {name: "You have time to waste simulation (100000 simulations)", value: 100000}
    ],
    nbSimulations: 100,

    histoAsStr : "S : 1 2 3 4 5 1 2 3 4 5 1 2 3 4 5 \n" +
    "M : 5 8 9 10 4 7 9 5 2 8 4 6 7 2 3 4 8 6 2 8 6 9 4 7 5 3 1 8 2 4 5 8 6 7 9 5 6 4 2 3 8 1 \n" +
        "XL : 12 42 37 22 53 25 56 37 41 36 25 14 53 38 44 22 15 47 38 29 53 27 52 32 44 36 25 16 58 39 42 23 \n"
        ,

    refresh : function(){

        var newHisto = [];
        _.each(this.histoAsStr.split("\n"),function(f){
            if ((f.match(":"))){
                var splitHisto = f.split(":");
                var historicalData = _.filter(splitHisto[1].split(/\s+/), function(value){return value.trim().length > 0});
                historicalData = _.map(historicalData, parseFloat);
                newHisto.push(App.HistoricalEstimation.create({id:splitHisto[0], historicalData:historicalData}));
            }
        });
        this.set('histo',newHisto );




    },


    estimate: function() {
        if (!this.needCompute()) {
            return ["not computable"];
        }

        var simulations = [];
        for (var j = 0; j<this.get('nbSimulations'); j++){
            var simulated = 0;
            this.get("histo").forEach(function(histo){
                for (var i = 0; i < histo.get('nbItemToEstimate'); i++){
                    var randomIndex = Math.floor(Math.random() * histo.get('historicalData').length);
                    simulated += histo.get('historicalData')[randomIndex];
                }
            });
            simulations.push(simulated)
        }
        simulations.sort(function(a, b){return a-b});


        return [
            "95 % of the time you will take less than " + simulations[Math.floor(this.nbSimulations*95/100)],
            "90 % of the time you will take less than " + simulations[Math.floor(this.nbSimulations*90/100)],
            "80 % of the time you will take less than " + simulations[Math.floor(this.nbSimulations*80/100)],
            "50 % of the time you will take less than " + simulations[Math.floor(this.nbSimulations*50/100)],
            "10 % of the time you will take less than " + simulations[Math.floor(this.nbSimulations*10/100)]
        ];

    }.property('histo.@each.nbItemToEstimate', 'nbSimulations'),

    needCompute: function(){
        var nbToEstimate = this.get("histo").getEach('nbItemToEstimate');

        for (var i = 0; i<nbToEstimate.length; i++){
            if (nbToEstimate[i] > 0){
                return true;
            }
        }
        return false;
    }

});

App.HistoricalEstimation = Ember.Object.extend({
    historicalData  : [],
    nbItemToEstimate : 0,

    nbData : function() {
        return this.get('historicalData').length;
    }.property('historicalData'),


    /**
     * create groups in order to have no groups with 0 entries inside
     */
    createRepartition: function(data){
        var nbPartition = 5;// chisquare10.length+1; // Each partition must contains at most
        var repartition = this._createRepartition(nbPartition, data);
        while (repartition.isTooBad()){
            repartition = this._createRepartition(--nbPartition, data);
        }
        return repartition;
    },

    _createRepartition : function (nbPartitions,values) {

        var repartition = {
            min : 0.8*_.min(values),
            max : 1.2*_.max(values),
            length : values.length,
            nbPartitions : nbPartitions,
            increments : (1.2*_.max(values)-0.8*_.min(values))/nbPartitions,
            partitions : [],
            getPercents: function(actualValues){
                var that = this;
                var percent = [];
                for (var i = 0; i<that.nbPartitions; i++){
                    var actual = 0;

                    _.each(actualValues, function(actualValue){
                        var minForPartition = that.min + i*that.increments;
                        var maxForPartition = minForPartition + that.increments;
                        if (actualValue >= minForPartition && ( actualValue < maxForPartition || (actualValue == that.max && i==nbPartitions-1))){
                            actual++;
                        }

                    });

                    var expected = that.partitions[i].length / that.length;
                    actual = actual / actualValues.length;
                    percent.push({
                        partition: that.partitions[i] ,
                        expected: expected,
                        actual: actual,
                        expectedPercent: Math.round(expected*100) + " %",
                        actualPercent: Math.round(actual*100) + " %"

                    });
                }
                return percent;
            },

            isTooBad : function(){
                var that = this;

                return _.some(that.partitions, function(v){return v.length ==0});

                /*
                var nbPartitionsWithZeroEntry =  0;
                var nbPartitionsWithAppropriateEntry =  0;

                _.each(that.partitions, function(partition){
                    if (partition.length  == 0){
                        nbPartitionsWithZeroEntry++;
                    } else if (partition.length  >= 3){
                        nbPartitionsWithAppropriateEntry++;
                    }
                });

                return (that.partitions.length-nbPartitionsWithZeroEntry) == 0 ||
                    nbPartitionsWithAppropriateEntry/(that.partitions.length-nbPartitionsWithZeroEntry) < 0.30
                */

            }
        };

        // initialisation;
        for (var i = 0; i < repartition.nbPartitions; i++) {
            repartition.partitions[i] = [];
        }
        _.each(values, function (value) {
            if (repartition.min == repartition.max){
                // case when all value equals in the sample data -> increment = 0
                repartition.partitions[0].push(value);
            } else {
                var index =  Math.min(Math.floor((value-repartition.min)/repartition.increments),nbPartitions - 1);
                repartition.partitions[index].push(value);
            }
        });



        return repartition;
    },






    testCHI2 : function() {
        var historicalValues = this.get('historicalData');
        if (this.get('historicalData').length < 10){
            return {result : "There is no enough historical data to check if the model of this category is reliable.", resultClass:"bad"};
        }

        if (_.min(this.get('historicalData')) == _.max(this.get('historicalData'))){
            return {result : "All entries for this category are equals. Estimation for this category will be constant", resultClass:"bad"};
        }

        var partition = _.partition(historicalValues, partitionFunction);

        var repartition = this.createRepartition(partition[0]);

        var chi2 = 0;
        var percents = repartition.getPercents(partition[1]);
        _.each(percents, function(percent){
            chi2 += (percent.expected-percent.actual)*(percent.expected-percent.actual)
                /percent.expected;
        });
        chi2 = Math.round(chi2*partition[1].length * 10000)/10000;
        var maxChi2 = chisquare10[repartition.nbPartitions-1];


        return {
            result : maxChi2 > chi2 ? "There is more than 80% chances your data may represent a reliable distribution" :
                "There is less than 80% chance that your data follow a common distribution",
            resultClass: maxChi2 > chi2 ? "good":"bad",
            chi2:chi2,
            maxChi2:maxChi2,
            repartition:repartition,
            percents:percents,
            testData:partition[1]
        };

    }.property('historicalData')





});



App.Router.map(function() {
  // put your routes here
});

App.IndexRoute = Ember.Route.extend({
  model: function() {
      var model =  App.Estimation.create({
          histo : []
      });
      model.refresh();
      return model;
  },
    actions: {
        refresh: function(model){
            model.refresh();
        },
        showDetails: function(){
            $(".chi2-details").toggle();
        },
        help : function(){
            $(".notice").toggle();
        }
    }

});

App.IndexController = Ember.ObjectController.extend({

});








